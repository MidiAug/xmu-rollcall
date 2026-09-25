import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:xmu_rollcall/core/logging/log_exporter.dart';
import 'package:xmu_rollcall/core/logging/log_record.dart';
import 'package:xmu_rollcall/core/logging/log_redactor.dart';
import 'package:xmu_rollcall/core/logging/memory_log_index.dart';
import 'package:xmu_rollcall/core/logging/ndjson_file_sink.dart';

/// Cross-platform diagnostic log facade (Windows / Android same API).
///
/// Always redacts via [LogRedactor]. Never log passwords or cookies.
abstract final class AppLog {
  static const _pendingCap = 200;

  static NdjsonFileSink? _sink;
  static MemoryLogIndex _index = MemoryLogIndex();
  static final List<LogRecord> _pending = [];
  static bool _ready = false;
  static bool _bootstrapping = false;
  static LogExporter? _exporter;
  static AppLifecycleListener? _lifecycle;

  /// UI listens here; file sink still gets NDJSON only.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static MemoryLogIndex get index => _index;

  static bool get sinkHealthy => _sink?.healthy ?? true;

  static int get droppedCount =>
      (_sink?.droppedCount ?? 0) + _pendingDropped;

  static int _pendingDropped = 0;

  static int get writeErrorCount => _sink?.writeErrorCount ?? 0;

  static int get corruptLineCount => _sink?.corruptLineCount ?? 0;

  /// Test / DI hook.
  @visibleForTesting
  static Future<void> resetForTest({
    NdjsonFileSink? sink,
    MemoryLogIndex? index,
  }) async {
    _lifecycle?.dispose();
    _lifecycle = null;
    try {
      await _sink?.close();
    } catch (_) {}
    _sink = sink;
    _index = index ?? MemoryLogIndex();
    _exporter = sink == null ? null : LogExporter(sink);
    _pending.clear();
    _pendingDropped = 0;
    _ready = sink != null;
    _bootstrapping = false;
    revision.value = 0;
  }

  static String newOpId() => const Uuid().v4();

  static Future<void> bootstrap({NdjsonFileSink? sink}) async {
    if (_ready || _bootstrapping) return;
    _bootstrapping = true;
    try {
      _sink = sink ?? NdjsonFileSink();
      _exporter = LogExporter(_sink!);
      await _sink!.open();
      final newest = await _sink!.readNewest(limit: _index.capacity);
      _index.preloadNewestFirst(newest);
      final pending = List<LogRecord>.from(_pending);
      _pending.clear();
      _ready = true;
      for (final r in pending) {
        _fanOut(r);
      }
      await _emitAppStart();
    } catch (_) {
      // Bootstrap failure must not crash the app.
      _ready = true;
      healthyMarkFailed();
    } finally {
      _bootstrapping = false;
    }
  }

  static void healthyMarkFailed() {
    _sink?.healthy = false;
  }

  /// Attach lifecycle logging (call once from app root after bootstrap).
  static void attachLifecycleListener() {
    _lifecycle?.dispose();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        event('app.lifecycle', level: 'I', fields: {
          'state': state.name,
        });
      },
    );
  }

  static void d(String message, {String tag = 'app'}) =>
      event('debug.$tag', level: 'D', fields: {'message': message});

  static void i(String message, {String tag = 'app'}) =>
      event('info.$tag', level: 'I', fields: {'message': message});

  static void w(String message, {String tag = 'app'}) =>
      event('warn.$tag', level: 'W', fields: {'message': message});

  static void e(String message, {String tag = 'app', Object? error}) {
    final fields = <String, dynamic>{'message': message};
    if (error != null) {
      fields.addAll(
        LogRedactor.exceptionFields(error: error, message: 'unexpected'),
      );
    }
    event('error.$tag', level: 'E', fields: fields);
  }

  static void event(
    String name, {
    String level = 'I',
    Map<String, dynamic>? fields,
    String? opId,
  }) {
    final redacted = LogRedactor.redactFields(fields, fallbackEvent: name);
    final record = LogRecord(
      ts: DateTime.now().toUtc(),
      level: level,
      event: name,
      opId: opId,
      fields: redacted,
    );
    if (!_ready) {
      _pending.insert(0, record);
      if (_pending.length > _pendingCap) {
        _pending.removeLast();
        _pendingDropped++;
      }
      if (kDebugMode) {
        debugPrint(_consoleLine(record));
      }
      return;
    }
    _fanOut(record);
  }

  static void logAppError({
    required Object error,
    StackTrace? stackTrace,
    required String source,
  }) {
    event(
      'app.error',
      level: 'E',
      fields: LogRedactor.exceptionFields(
        error: error,
        stackTrace: stackTrace,
        source: source,
        message: _safeErrorHint(error),
      ),
    );
    unawaited(flush());
  }

  static Future<void> flush() async {
    await _sink?.flush();
  }

  static Future<LogExportResult?> exportLogs({bool share = true}) async {
    final exporter = _exporter;
    if (exporter == null) return null;
    await flush();
    return exporter.exportAndShare(share: share);
  }

  static void _fanOut(LogRecord record) {
    _index.add(record);
    revision.value++;
    if (kDebugMode) {
      debugPrint(_consoleLine(record));
    }
    unawaited(_sink?.appendLine(record.toNdjsonLine()) ?? Future.value());
  }

  /// Human-readable console line; NDJSON stays on disk for export/grep.
  ///
  /// Classic bracket style, e.g. `[I] 09:58:45 [rollcall] list.refresh count=3`.
  static String _consoleLine(LogRecord r) {
    final t = r.ts.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    final tag = r.event.contains('.') ? r.event.split('.').first : 'app';
    final bits = <String>[];
    if (r.opId != null && r.opId!.isNotEmpty) {
      final id = r.opId!;
      bits.add('op=${id.length > 8 ? '${id.substring(0, 8)}…' : id}');
    }
    r.fields.forEach((k, v) {
      if (v == null) return;
      // Skip huge / nested maps on console; file still has full fields.
      if (v is Map || v is List) return;
      var s = '$v';
      if (s.isEmpty) return;
      if (s.length > 80) s = '${s.substring(0, 77)}…';
      bits.add('$k=$s');
    });
    final tail = bits.isEmpty ? '' : ' ${bits.join(' ')}';
    return '[${r.level}] $hh:$mm:$ss [$tag] ${r.event}$tail';
  }

  static String _safeErrorHint(Object error) {
    String raw;
    if (error is AssertionError) {
      raw = error.message?.toString() ?? error.toString();
    } else {
      raw = error.toString();
    }
    final first = raw.split('\n').first.trim();
    if (first.isEmpty) return error.runtimeType.toString();
    return LogRedactor.scrubString(first);
  }

  static Future<void> _emitAppStart() async {
    String version = '?';
    String build = '?';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      build = info.buildNumber;
    } catch (_) {}
    event('app.start', level: 'I', fields: {
      'appVersion': version,
      'buildNumber': build,
      'platform': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
    });
  }
}
