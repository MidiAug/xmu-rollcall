import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';
import 'package:xmu_rollcall/features/rollcall/desktop_qr_preview.dart';
import 'package:xmu_rollcall/features/rollcall/desktop_qr_window.dart';

Future<void> main(List<String> arguments) async {
  final startup = Stopwatch()..start();
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (PlatformHooks.isWindows) {
        final window = await WindowController.fromCurrentEngine();
        if (window.arguments.isNotEmpty) {
          final config = jsonDecode(window.arguments) as Map;
          if (config['kind'] == 'desktop_qr') {
            runApp(
              DesktopQrScanApp(
                controller: window,
                owner: WindowController.fromWindowId(
                  config['ownerWindowId'] as String,
                ),
              ),
            );
            return;
          }
        }
      }
      if (PlatformHooks.isAndroid) {
        FlutterForegroundTask.initCommunicationPort();
      }

      FlutterError.onError = (details) {
        AppLog.logAppError(
          error: details.exception,
          stackTrace: details.stack,
          source: 'flutter',
        );
        FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        AppLog.logAppError(error: error, stackTrace: stack, source: 'platform');
        return true;
      };

      await PlatformHooks.initOptional();
      AppLog.attachLifecycleListener();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppLog.event(
          'app.first_frame',
          fields: {
            'elapsedMs': startup.elapsedMilliseconds,
            'buildMode': kReleaseMode
                ? 'release'
                : kProfileMode
                ? 'profile'
                : 'debug',
          },
        );
        unawaited(AppLog.bootstrap());
      });
      if (kDebugMode && arguments.contains('--preview-desktop-qr')) {
        runApp(const DesktopQrPreviewApp());
        return;
      }
      runApp(const ProviderScope(child: XmuRollcallApp()));
    },
    (error, stack) {
      AppLog.logAppError(error: error, stackTrace: stack, source: 'zone');
    },
  );
}
