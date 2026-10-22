import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';

/// Owns a separate Flutter engine/window; the account-bearing main engine stays put.
abstract final class DesktopQrScanner {
  static bool get supported => !kIsWeb && Platform.isWindows;
  static WindowController? _child;
  static WindowController? _owner;
  static Completer<void>? _ready;
  static Completer<String?>? _result;
  static int _session = 0;

  static Future<void> _initializeOwner() async {
    if (_owner != null) return;
    final owner = await WindowController.fromCurrentEngine();
    await owner.setWindowMethodHandler((call) async {
      final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
      switch (call.method) {
        case 'qr_ready':
          if (_ready?.isCompleted == false) _ready!.complete();
        case 'qr_complete':
          if (args['sessionId'] == _session && _result?.isCompleted == false) {
            _result!.complete(args['raw'] as String?);
          }
        case 'qr_log':
          final event = args['event'] as String? ?? '';
          if (event.startsWith('qr.desktop.')) {
            AppLog.event(
              event,
              level: args['level'] as String? ?? 'I',
              fields: Map<String, dynamic>.from(args['fields'] as Map? ?? {}),
            );
          }
      }
      return null;
    });
    _owner = owner;
  }

  static Future<String?> open({
    int? rollcallId,
    String? courseId,
    bool preview = false,
  }) async {
    if (!supported) throw UnsupportedError('屏幕扫码目前支持 Windows');
    if (_result != null) throw StateError('扫码窗口已打开');
    final result = _result = Completer<String?>();
    final session = ++_session;
    AppLog.event(
      'qr.desktop.open',
      fields: {'rollcallId': rollcallId, 'preview': preview},
    );
    try {
      await _initializeOwner();
      if (result.isCompleted) return null;
      if (_child == null) {
        _ready = Completer<void>();
        _child = await WindowController.create(
          WindowConfiguration(
            hiddenAtLaunch: true,
            arguments: jsonEncode({
              'kind': 'desktop_qr',
              'ownerWindowId': _owner!.windowId,
            }),
          ),
        );
      }
      await Future.any([
        _ready!.future.timeout(const Duration(seconds: 20)),
        result.future.then<void>((_) {}),
      ]);
      if (result.isCompleted) return null;
      await _child!.invokeMethod('scan_start', {
        'sessionId': session,
        'rollcallId': rollcallId,
        'courseId': courseId,
        'preview': preview,
      });
      final raw = await result.future;
      AppLog.event(
        'qr.desktop.close',
        fields: {
          'rollcallId': rollcallId,
          'captured': raw != null,
          'preview': preview,
        },
      );
      return raw;
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'qr.desktop.open',
      );
      if (_child != null) {
        try {
          await _child!.hide();
        } catch (_) {}
      }
      _child = null;
      rethrow;
    } finally {
      if (_result == result) {
        _result = null;
      }
    }
  }

  static Future<void> cancel() async {
    final result = _result;
    if (result == null || result.isCompleted) return;
    result.complete(null);
    if (_child != null && _ready?.isCompleted == true) {
      try {
        await _child!.invokeMethod('scan_cancel');
      } catch (error) {
        AppLog.event(
          'qr.desktop.cancel_error',
          level: 'W',
          fields: {'errorType': error.runtimeType.toString()},
        );
      }
    }
  }
}
