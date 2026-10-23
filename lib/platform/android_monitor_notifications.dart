import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    show FlutterForegroundTask;
import 'package:xmu_rollcall/app/app_brand.dart';

/// Shared by the UI and the service isolate; no UI navigation dependency.
class AndroidMonitorNotifications {
  final plugin = FlutterLocalNotificationsPlugin();
  static const discoveryChannelId = 'monitor_discovery';
  static const discoveryPayload = 'rollcall';

  Future<void> discovered({
    required String runId,
    required int count,
    String? courseTitle,
    Future<void> Function()? requireCurrent,
  }) async {
    final foreground = await FlutterForegroundTask.isAppOnForeground;
    await requireCurrent?.call();
    if (foreground) {
      FlutterForegroundTask.sendDataToMain({
        'action': 'foreground_notice',
        'runId': runId,
        'message': '${courseTitle ?? ''} 发现签到 $count 条，点击卡片可处理',
      });
      return;
    }
    await show(count: count, courseTitle: courseTitle);
  }

  Future<void> showResult({
    required String runId,
    required String courseTitle,
    required bool ok,
    Future<void> Function()? requireCurrent,
  }) async {
    final body = '$courseTitle：${ok ? '自动签到成功' : '自动签到未成功，请打开签到页处理'}';
    final foreground = await FlutterForegroundTask.isAppOnForeground;
    await requireCurrent?.call();
    if (foreground) {
      FlutterForegroundTask.sendDataToMain({
        'action': 'foreground_notice',
        'runId': runId,
        'message': body,
      });
      return;
    }
    await show(count: 1, body: body, quiet: true);
  }

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
    String? body,
    bool quiet = false,
  }) async {
    await plugin.show(
      id: diagnostic ? 2699 : 2602,
      title: diagnostic ? '厦大签到  通知测试' : kAppDisplayName,
      body:
          body ??
          (diagnostic
              ? '后台通知测试已发送；请确认实际收到提醒'
              : '${courseTitle?.isNotEmpty == true ? '$courseTitle：' : ''}发现进行中签到 $count 条，继续检测'),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          discoveryChannelId,
          '签到发现',
          channelDescription: '发现进行中签到时提醒',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: !quiet,
          playSound: !quiet,
          silent: quiet,
          onlyAlertOnce: quiet,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
      payload: discoveryPayload,
    );
  }
}
