import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:xmu_rollcall/app/app_brand.dart';
import 'package:xmu_rollcall/platform/desktop_notification_content.dart';

/// Windows sender identity and payload for compact text-only notifications.
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

  Future<void> show(
    DesktopNotificationContent content, {
    required bool test,
    bool silent = false,
  }) => plugin.show(
    id: test ? 2 : 1,
    title: content.title,
    body: content.body,
    payload: test ? testPayload : discoveryPayload,
    notificationDetails: WindowsNotificationDetails(
      // The small sender icon belongs to Windows identity (iconPath).
      // appLogoOverride adds a second, large image in the message body.
      audio: silent ? WindowsNotificationAudio.silent() : null,
    ),
  );
}
