import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:xmu_rollcall/app/app_brand.dart';

/// Windows identity, image and payload shared by test, discovery and result toasts.
class WindowsDesktopNotifications {
  WindowsDesktopNotifications({required this.plugin, Uri? iconUri})
    : iconUri = iconUri ?? bundledIconUri();

  final FlutterLocalNotificationsWindows plugin;
  final Uri iconUri;

  static const discoveryPayload = 'rollcall-found';
  static const testPayload = 'rollcall-notification-test';

  /// Resolve from the executable, so shortcuts with a different working directory
  /// still find the Flutter asset in both debug and portable release builds.
  static Uri bundledIconUri() => File(
    Platform.resolvedExecutable,
  ).parent.uri.resolve('data/flutter_assets/assets/tray/tray_icon.png');

  Future<bool> initialize(DidReceiveNotificationResponseCallback onResponse) =>
      plugin.initialize(
        settings: WindowsInitializationSettings(
          appName: kAppDisplayName,
          appUserModelId: 'cn.edu.xmu.rollcall',
          guid: '1a7ff90c-8c39-4cad-9d09-702731e97bba',
          iconPath: File.fromUri(iconUri).path,
        ),
        onDidReceiveNotificationResponse: onResponse,
      );

  Future<void> show(String body, {required bool test, bool silent = false}) =>
      plugin.show(
        id: test ? 2 : 1,
        title: test ? '测试通知' : '签到提醒',
        body: body,
        payload: test ? testPayload : discoveryPayload,
        notificationDetails: WindowsNotificationDetails(
          images: [
            WindowsImage(
              iconUri,
              altText: kAppDisplayName,
              placement: WindowsImagePlacement.appLogoOverride,
            ),
          ],
          audio: silent ? WindowsNotificationAudio.silent() : null,
        ),
      );
}
