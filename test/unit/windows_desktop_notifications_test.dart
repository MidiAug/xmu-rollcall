import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/platform/windows_desktop_notifications.dart';

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
    'all native toasts carry a bundled logo; quiet updates reuse discovery id',
    () async {
      await notifications.show('test', test: true);
      await notifications.show('discovered', test: false);
      await notifications.show('result', test: false, silent: true);
      expect(plugin.calls.map((call) => call.id), [2, 1, 1]);
      expect(plugin.calls.map((call) => call.payload), [
        WindowsDesktopNotifications.testPayload,
        WindowsDesktopNotifications.discoveryPayload,
        WindowsDesktopNotifications.discoveryPayload,
      ]);
      expect(plugin.calls.first.title, '测试通知');
      expect(plugin.calls[1].title, '签到提醒');
      for (final call in plugin.calls) {
        final image = call.details!.images.single;
        expect(image.uri, icon);
        expect(image.placement, WindowsImagePlacement.appLogoOverride);
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
        notifications.show('test', test: true),
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
