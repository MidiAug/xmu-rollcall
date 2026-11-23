import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/platform/android_monitor_shell.dart';
import 'package:xmu_rollcall/platform/android_monitor_store.dart';
import 'package:xmu_rollcall/platform/android_monitor_task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_foreground_task/methods');
  var running = false;
  var starts = 0;
  var stops = 0;
  final sentToTask = <Map<String, dynamic>>[];
  late Completer<void> stopped;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'user_id': '1'});
    FlutterForegroundTask.resetStatic();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'test',
        channelName: 'test',
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(2000),
      ),
    );
    running = false;
    starts = stops = 0;
    sentToTask.clear();
    stopped = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'isRunningService') return running;
          if (call.method == 'startService') {
            starts++;
            running = true;
          }
          if (call.method == 'stopService') {
            stops++;
            running = false;
            if (!stopped.isCompleted) stopped.complete();
          }
          if (call.method == 'sendData') {
            final raw = call.arguments;
            if (raw is String) {
              sentToTask.add(Map<String, dynamic>.from(jsonDecode(raw) as Map));
            } else if (raw is Map) {
              sentToTask.add(Map<String, dynamic>.from(raw));
            }
          }
          return null;
        });
  });

  tearDown(() {
    FlutterForegroundTask.resetStatic();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'one Android service hosts two accounts and stopping one preserves the service',
    () async {
      final shell = AndroidMonitorShell.instance;
      for (final id in [1, 2]) {
        expect(
          await shell.startMonitor(
            userId: id,
            ownerUserId: 1,
            assistUserId: id == 1 ? null : id,
            config: const MonitorConfig(),
            cookies: '[]',
            deviceId: 'test-$id',
            runId: 'run-$id',
          ),
          'run-$id',
        );
      }
      expect(starts, 1);
      expect(stops, 0);
      expect(
        sentToTask.any((m) => m['action'] == 'runs_changed'),
        isTrue,
      );
      expect((await AndroidMonitorStore.readRuns()).length, 2);

      await shell.updateConfig(
        const MonitorConfig(autoAnswer: true),
        assistUserId: 2,
      );
      expect(
        (await AndroidMonitorStore.readRun(runId: 'run-1'))!.config.autoAnswer,
        isFalse,
      );
      expect(
        (await AndroidMonitorStore.readRun(runId: 'run-2'))!.config.autoAnswer,
        isTrue,
      );
      expect(
        sentToTask.any((m) => m['action'] == 'config' && m['runId'] == 'run-2'),
        isTrue,
      );

      await shell.pollNow(assistUserId: 2, manual: false);
      expect(
        sentToTask.any(
          (m) =>
              m['action'] == 'poll_now' &&
              m['runId'] == 'run-2' &&
              m['manual'] == false,
        ),
        isTrue,
      );

      final assistStatus = await shell.readStatus(assistUserId: 2);
      expect(assistStatus?['runId'], 'run-2');
      expect(assistStatus?['assistUserId'], 2);
      expect(assistStatus?['autoAnswer'], isTrue);

      await shell.stopAccount(assistUserId: 2);
      expect(running, isTrue);
      expect(stops, 0);
      expect((await AndroidMonitorStore.readRuns()).single.id, 'run-1');

      await shell.stopOngoing();
      expect(running, isFalse);
      expect(stops, 1);
    },
  );

  test(
    'notification stop revokes all grants before workers initialize',
    () async {
      for (final id in [1, 2]) {
        await AndroidMonitorStore.writeRun(
          AndroidMonitorRun(
            id: 'run-$id',
            userId: id,
            ownerUserId: 1,
            assistUserId: id == 1 ? null : id,
            config: const MonitorConfig(),
          ),
        );
        await const FlutterSecureStorage().write(
          key: 'monitor_credential_run-$id',
          value: 'test',
        );
      }
      running = true;
      AndroidMonitorTaskHandler().onNotificationButtonPressed('stop');
      await stopped.future.timeout(const Duration(seconds: 2));
      expect(await AndroidMonitorStore.readRuns(), isEmpty);
      for (final id in [1, 2]) {
        expect(
          await const FlutterSecureStorage().read(
            key: 'monitor_credential_run-$id',
          ),
          isNull,
        );
      }
    },
  );
}
