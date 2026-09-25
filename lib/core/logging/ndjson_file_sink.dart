import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:xmu_rollcall/core/logging/log_record.dart';

/// Serial NDJSON file sink with rotation and retention.
class NdjsonFileSink {
  NdjsonFileSink({
    Directory? logsDir,
    this.maxFileBytes = 1048576,
    this.maxTotalBytes = 8 * 1048576,
    this.maxAge = const Duration(days: 7),
    this.activeFileName = 'app.ndjson',
  }) : _injectedDir = logsDir;

  final Directory? _injectedDir;
  final int maxFileBytes;
  final int maxTotalBytes;
  final Duration maxAge;
  final String activeFileName;

  Directory? _dir;
  IOSink? _ioSink;
  File? _activeFile;
  Future<void> _chain = Future.value();

  bool healthy = true;
  int droppedCount = 0;
  int writeErrorCount = 0;
  int corruptLineCount = 0;

  Directory? get logsDirectory => _dir;

  Future<T> enqueue<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _chain = _chain.then((_) async {
      try {
        final result = await task();
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        healthy = false;
        writeErrorCount++;
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    }).catchError((_) {
      // Prior task failure already counted; keep chain alive.
    });
    return completer.future;
  }

  Future<void> open() => enqueue(() async {
        _dir = _injectedDir ??
            Directory(
              '${(await getApplicationSupportDirectory()).path}/logs',
            );
        if (!await _dir!.exists()) {
          await _dir!.create(recursive: true);
        }
        _activeFile = File('${_dir!.path}/$activeFileName');
        if (!await _activeFile!.exists()) {
          await _activeFile!.create(recursive: true);
        }
        await _ioSink?.close();
        _ioSink = _activeFile!.openWrite(mode: FileMode.append);
      });

  Future<void> appendLine(String line) => enqueue(() async {
        await _ensureOpen();
        try {
          _ioSink!.writeln(line);
          await _ioSink!.flush();
          await _rotateIfNeeded();
          await _enforceRetention();
        } catch (_) {
          healthy = false;
          writeErrorCount++;
          droppedCount++;
        }
      });

  Future<void> flush() => enqueue(() async {
        await _ioSink?.flush();
      });

  /// Newest-first valid records from all NDJSON files (active + rotated).
  Future<List<LogRecord>> readNewest({required int limit}) =>
      enqueue(() async {
        await _ensureOpen();
        final files = await _listNdjsonNewestFirst();
        final out = <LogRecord>[];
        for (final file in files) {
          if (out.length >= limit) break;
          List<String> lines;
          try {
            final text = await file.readAsString();
            lines = const LineSplitter().convert(text);
          } catch (_) {
            corruptLineCount++;
            continue;
          }
          for (var i = lines.length - 1; i >= 0; i--) {
            if (out.length >= limit) break;
            final rec = LogRecord.tryParse(lines[i]);
            if (rec == null) {
              if (lines[i].trim().isNotEmpty) corruptLineCount++;
              continue;
            }
            out.add(rec);
          }
        }
        return out;
      });

  Future<List<File>> listNdjsonFiles() => enqueue(() async {
        await _ensureOpen();
        return _listNdjsonNewestFirst();
      });

  /// Copy every NDJSON into [destDir]; returns copied files (in dest).
  Future<List<File>> copyAllTo(Directory destDir) => enqueue(() async {
        await _ensureOpen();
        await _ioSink?.flush();
        if (!await destDir.exists()) {
          await destDir.create(recursive: true);
        }
        final sources = await _listNdjsonNewestFirst();
        final copied = <File>[];
        for (final src in sources) {
          final dest = File('${destDir.path}/${src.uri.pathSegments.last}');
          await src.copy(dest.path);
          copied.add(dest);
        }
        return copied;
      });

  Future<void> close() => enqueue(() async {
        await _ioSink?.flush();
        await _ioSink?.close();
        _ioSink = null;
      });

  Future<void> _ensureOpen() async {
    if (_dir != null && _ioSink != null && _activeFile != null) return;
    _dir ??= _injectedDir ??
        Directory('${(await getApplicationSupportDirectory()).path}/logs');
    if (!await _dir!.exists()) {
      await _dir!.create(recursive: true);
    }
    _activeFile = File('${_dir!.path}/$activeFileName');
    if (!await _activeFile!.exists()) {
      await _activeFile!.create(recursive: true);
    }
    _ioSink ??= _activeFile!.openWrite(mode: FileMode.append);
  }

  Future<void> _rotateIfNeeded() async {
    final length = await _activeFile!.length();
    if (length < maxFileBytes) return;
    await _ioSink?.flush();
    await _ioSink?.close();
    _ioSink = null;
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final rotated = File('${_dir!.path}/app-$stamp.ndjson');
    await _activeFile!.rename(rotated.path);
    _activeFile = File('${_dir!.path}/$activeFileName');
    await _activeFile!.create(recursive: true);
    _ioSink = _activeFile!.openWrite(mode: FileMode.append);
  }

  Future<void> _enforceRetention() async {
    final files = await _listNdjsonOldestFirst();
    final cutoff = DateTime.now().toUtc().subtract(maxAge);
    // Delete by age first (oldest first), skipping active file name only if
    // it is the current open handle — rotated files use app-*.ndjson.
    for (final file in List<File>.from(files)) {
      final name = file.uri.pathSegments.last;
      if (name == activeFileName) continue;
      final stat = await file.stat();
      if (stat.modified.toUtc().isBefore(cutoff)) {
        try {
          await file.delete();
        } catch (_) {
          healthy = false;
          writeErrorCount++;
        }
      }
    }
    // Then by total size.
    while (true) {
      final remaining = await _listNdjsonOldestFirst();
      var total = 0;
      for (final f in remaining) {
        total += await f.length();
      }
      if (total <= maxTotalBytes) break;
      File? victim;
      for (final f in remaining) {
        if (f.uri.pathSegments.last == activeFileName) continue;
        victim = f;
        break;
      }
      if (victim == null) break;
      try {
        await victim.delete();
      } catch (_) {
        healthy = false;
        writeErrorCount++;
        break;
      }
    }
  }

  Future<List<File>> _listNdjsonOldestFirst() async {
    final list = await _dir!
        .list()
        .where((e) => e is File && e.path.endsWith('.ndjson'))
        .cast<File>()
        .toList();
    list.sort((a, b) => a.path.compareTo(b.path));
    return list;
  }

  Future<List<File>> _listNdjsonNewestFirst() async {
    final list = await _listNdjsonOldestFirst();
    return list.reversed.toList();
  }
}
