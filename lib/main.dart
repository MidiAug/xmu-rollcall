import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
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
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'platform',
      );
      return true;
    };

    await PlatformHooks.initOptional();
    await AppLog.bootstrap();
    AppLog.attachLifecycleListener();
    runApp(const ProviderScope(child: XmuRollcallApp()));
  }, (error, stack) {
    AppLog.logAppError(
      error: error,
      stackTrace: stack,
      source: 'zone',
    );
  });
}
