import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/platform/windows_desktop_notifications.dart';
import 'package:xmu_rollcall/platform/desktop_notification_content.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

class _WindowsPlugin extends Fake implements FlutterLocalNotificationsWindows {
  WindowsInitializationSettings? settings;
  DidReceiveNotificationResponseCallback? onResponse;
  final calls =
      <
        ({
          int id,
          String? title,
          String? body,
          String? payload,
          WindowsNotificationDetails? details,
        })
      >[];
  bool initialized = true;
  bool failShow = false;
  @override
  Future<bool> initialize({
    required WindowsInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async {
    this.settings = settings;
    onResponse = onDidReceiveNotificationResponse;
    return initialized;
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    String? payload,
    WindowsNotificationDetails? notificationDetails,
  }) async {
    if (failShow) throw StateError('Windows rejected notification');
    calls.add((
      id: id,
      title: title,
      body: body,
      payload: payload,
      details: notificationDetails,
    ));
  }
}

void main() {
  final icon = Uri.file(
    r'C:\应用目录\data\flutter_assets\assets\tray\tray_icon.png',
    windows: true,
  );
  late _WindowsPlugin plugin;
  late WindowsDesktopNotifications notifications;
  setUp(() {
    plugin = _WindowsPlugin();
    notifications = WindowsDesktopNotifications(plugin: plugin, iconUri: icon);
  });
  test(
    'native initialization receives absolute icon and retains activation payload',
    () async {
      String? payload;
      expect(
        await notifications.initialize(
          (response) => payload = response.payload,
        ),
        isTrue,
      );
      expect(plugin.settings!.iconPath, File.fromUri(icon).path);
      expect(plugin.settings!.appUserModelId, 'cn.edu.xmu.rollcall');
      plugin.onResponse!(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: WindowsDesktopNotifications.testPayload,
        ),
      );
      expect(payload, WindowsDesktopNotifications.testPayload);
      plugin.initialized = false;
      expect(await notifications.initialize((_) {}), isFalse);
    },
  );
  test(
    'native toasts keep the header identity, show course/type and have no body image',
    () async {
      await notifications.show(DesktopNotificationContent.test, test: true);
      final item = RollcallItem.fromJson({
        'rollcall_id': 3,
        'course_title': '工程伦理',
        'is_radar': true,
      });
      await notifications.show(
        DesktopNotificationContent.discovery([item]),
        test: false,
      );
      await notifications.show(
        DesktopNotificationContent.result(item, true),
        test: false,
        silent: true,
      );
      expect(plugin.calls.map((call) => call.id), [2, 1, 1]);
      expect(plugin.calls.map((call) => call.payload), [
        WindowsDesktopNotifications.testPayload,
        WindowsDesktopNotifications.discoveryPayload,
        WindowsDesktopNotifications.discoveryPayload,
      ]);
      expect(plugin.calls.first.title, '示例课程（通知测试）');
      expect(plugin.calls.first.body, '雷达签到 · 点击返回应用');
      expect(plugin.calls[1].title, '工程伦理');
      expect(plugin.calls[1].body, contains('雷达签到'));
      expect(plugin.calls.last.body, contains('自动签到成功'));
      for (final call in plugin.calls) {
        expect(call.details!.images, isEmpty);
      }
      expect(plugin.calls.first.details!.audio, isNull);
      expect(plugin.calls.last.details!.audio, isNotNull);
    },
  );
  test(
    'native errors reach delivery policy instead of claiming success',
    () async {
      plugin.failShow = true;
      await expectLater(
        notifications.show(DesktopNotificationContent.test, test: true),
        throwsStateError,
      );
    },
  );
  test(
    'portable logo path is executable-relative and independent of working directory',
    () {
      final expected = File(
        Platform.resolvedExecutable,
      ).parent.uri.resolve('data/flutter_assets/assets/tray/tray_icon.png');
      final before = Directory.current;
      final temporary = Directory.systemTemp.createTempSync('xmu-notify-path-');
      try {
        Directory.current = temporary;
        expect(WindowsDesktopNotifications.bundledIconUri(), expected);
      } finally {
        Directory.current = before;
        temporary.deleteSync();
      }
    },
  );
}
