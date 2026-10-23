import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    show FlutterForegroundTask;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/platform/android_monitor_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = MethodChannel('flutter_foreground_task/methods');
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  var foreground = false;
  final system = <MethodCall>[];
  final messages = <Map>[];
  late Completer<Map> received;
  void receive(Object data) {
    messages.add(data as Map);
    if (!received.isCompleted) received.complete(data);
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    foreground = false;
    system.clear();
    messages.clear();
    received = Completer<Map>();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(receive);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(service, (call) async {
          if (call.method == 'isAppOnForeground') return foreground;
          if (call.method == 'sendData') messages.add(call.arguments as Map);
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, (call) async {
          if (call.method == 'show') system.add(call);
          return true;
        });
  });
  tearDown(() async {
    FlutterForegroundTask.removeTaskDataCallback(receive);
    await FlutterForegroundTask.streamSubscription?.cancel();
    FlutterForegroundTask.receivePort?.close();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(service, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notifications, null);
  });
  test(
    'foreground discovery routes to UI with run identity; background uses native notification',
    () async {
      final delivery = AndroidMonitorNotifications();
      foreground = true;
      await delivery.discovered(runId: 'r', count: 1, courseTitle: 'course');
      await received.future.timeout(const Duration(seconds: 2));
      expect(system, isEmpty);
      expect(messages.single['runId'], 'r');
      foreground = false;
      await delivery.discovered(runId: 'r', count: 1);
      expect(system, hasLength(1));
    },
  );
  test(
    'background results replace discovery quietly; revoked runs do not send',
    () async {
      final delivery = AndroidMonitorNotifications();
      await delivery.showResult(runId: 'r', courseTitle: 'course', ok: true);
      final args = system.single.arguments as Map;
      expect(args['id'], 2602);
      expect((args['platformSpecifics'] as Map)['silent'], true);
      await expectLater(
        delivery.discovered(
          runId: 'old',
          count: 1,
          requireCurrent: () async {
            throw StateError('account changed');
          },
        ),
        throwsStateError,
      );
      expect(system, hasLength(1));
    },
  );
}
