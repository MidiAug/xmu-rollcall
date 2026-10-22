import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:xmu_rollcall/app/app_brand.dart';

/// Shared by the UI and the service isolate; no UI navigation dependency.
class AndroidMonitorNotifications {
  final plugin = FlutterLocalNotificationsPlugin();
  static const discoveryChannelId = 'monitor_discovery';
  static const discoveryPayload = 'rollcall';

  Future<void> init({void Function(NotificationResponse)? onResponse}) async {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: onResponse,
    );
    await plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            discoveryChannelId,
            '签到发现',
            description: '发现进行中签到时提醒',
            importance: Importance.high,
            enableVibration: true,
          ),
        );
  }

  Future<void> show({
    required int count,
    bool diagnostic = false,
    String? courseTitle,
  }) async {
    await plugin.show(
      id: diagnostic ? 2699 : 2602,
      title: diagnostic ? '厦大签到  通知测试' : kAppDisplayName,
      body: diagnostic
          ? '后台通知测试成功；请确认收到声音和震动'
          : '${courseTitle?.isNotEmpty == true ? '$courseTitle：' : ''}发现进行中签到 $count 条，继续检测',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          discoveryChannelId,
          '签到发现',
          channelDescription: '发现进行中签到时提醒',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
      payload: discoveryPayload,
    );
  }
}
