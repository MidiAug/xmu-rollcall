import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:xmu_rollcall/app/app_brand.dart';
import 'package:xmu_rollcall/app/shell_navigation.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/platform/android_monitor_task.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

/// Android FGS ongoing monitor + discovery local notifications.
class AndroidMonitorShell {
  AndroidMonitorShell._();

  static final AndroidMonitorShell instance = AndroidMonitorShell._();

  static const _ongoingServiceId = 2601;
  static const _discoveryNotificationId = 2602;
  static const _discoveryPayload = 'rollcall';
  static const _ongoingChannelId = 'monitor_ongoing';
  static const _discoveryChannelId = 'monitor_discovery';

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;
  var _fgsConfigured = false;

  VoidCallback? stopMonitor;
  void Function(String message)? onUserMessage;

  Future<void> init() async {
    if (!PlatformHooks.isAndroid || _ready) return;

    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _configureFgsOptions();
    await _initLocalNotifications();

    PlatformHooks.onRollcallsDiscovered = notifyRollcallsDiscovered;
    _ready = true;
    AppLog.event('shell.android_ready', fields: {'ok': true});

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse?.payload == _discoveryPayload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ShellNavigation.instance.openRollcall(popToRoot: true);
      });
    }
  }

  void _configureFgsOptions() {
    if (_fgsConfigured) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _ongoingChannelId,
        channelName: '签到检测',
        channelDescription: '自动检测进行中时显示',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        enableVibration: false,
        playSound: false,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(2000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: false,
        stopWithTask: true,
      ),
    );
    _fgsConfigured = true;
  }

  Future<void> _initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    if (response.payload == _discoveryPayload) {
      ShellNavigation.instance.openRollcall(popToRoot: true);
    }
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final action = data['action'];
    if (action == 'dismissed') {
      AppLog.event('shell.android_ongoing_dismissed');
      stopMonitor?.call();
      onUserMessage?.call('检测已停止');
      return;
    }
    if (action == 'timeout') {
      AppLog.event('shell.android_fgs_timeout');
      stopMonitor?.call();
      onUserMessage?.call('后台检测已达系统时限，已停止');
    }
  }

  /// Ensure notification permission. Returns false if denied.
  Future<bool> prepareStart() async {
    if (!PlatformHooks.isAndroid) return true;
    if (!_ready) await init();
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission == NotificationPermission.granted) return true;
    final after = await FlutterForegroundTask.requestNotificationPermission();
    return after == NotificationPermission.granted;
  }

  Future<bool> startOngoing({DateTime? nextPollAt}) async {
    if (!PlatformHooks.isAndroid) return true;
    if (!_ready) await init();
    _configureFgsOptions();

    final ms = nextPollAt?.millisecondsSinceEpoch;
    if (ms != null) {
      await FlutterForegroundTask.saveData(key: 'nextPollAtMs', value: ms);
    }

    if (await FlutterForegroundTask.isRunningService) {
      await syncNextPollAt(nextPollAt);
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: _ongoingServiceId,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: '厦大签到检测中',
      notificationText: formatMonitorCountdown(nextPollAt),
      callback: androidMonitorTaskCallback,
    );
    if (result is ServiceRequestFailure) {
      AppLog.logAppError(
        error: result.error,
        stackTrace: StackTrace.current,
        source: 'android_fgs_start',
      );
      return false;
    }
    AppLog.event('shell.android_fgs_start');
    return true;
  }

  Future<void> syncNextPollAt(DateTime? nextPollAt) async {
    if (!PlatformHooks.isAndroid) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    final ms = nextPollAt?.millisecondsSinceEpoch;
    if (ms != null) {
      await FlutterForegroundTask.saveData(key: 'nextPollAtMs', value: ms);
      FlutterForegroundTask.sendDataToTask({'nextPollAtMs': ms});
    }
    await FlutterForegroundTask.updateService(
      notificationTitle: '厦大签到检测中',
      notificationText: formatMonitorCountdown(nextPollAt),
    );
  }

  Future<void> stopOngoing() async {
    if (!PlatformHooks.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
        AppLog.event('shell.android_fgs_stop');
      }
    } catch (e, st) {
      AppLog.logAppError(error: e, stackTrace: st, source: 'android_fgs_stop');
    }
  }

  /// Discovery alert when app is not in the foreground.
  Future<void> notifyRollcallsDiscovered(int count) async {
    if (!PlatformHooks.isAndroid || count <= 0) return;
    try {
      final inFg = await FlutterForegroundTask.isAppOnForeground;
      if (inFg) return;

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _discoveryChannelId,
          '签到发现',
          channelDescription: '发现进行中签到时提醒',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await _plugin.show(
        id: _discoveryNotificationId,
        title: kAppDisplayName,
        body: '发现进行中签到 $count 条，检测已停止',
        notificationDetails: details,
        payload: _discoveryPayload,
      );
      AppLog.event('shell.android_notify_found', fields: {'count': count});
    } catch (e, st) {
      AppLog.logAppError(
        error: e,
        stackTrace: st,
        source: 'android_notify',
      );
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    if (!PlatformHooks.isAndroid) return;
    await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
  }
}

/// Binds [AndroidMonitorShell] to Riverpod stop callback + toast sink.
class AndroidMonitorShellBinder extends StatefulWidget {
  const AndroidMonitorShellBinder({
    super.key,
    required this.stopMonitor,
    required this.onUserMessage,
    required this.child,
  });

  final VoidCallback stopMonitor;
  final void Function(String message) onUserMessage;
  final Widget child;

  @override
  State<AndroidMonitorShellBinder> createState() =>
      _AndroidMonitorShellBinderState();
}

class _AndroidMonitorShellBinderState extends State<AndroidMonitorShellBinder> {
  @override
  void initState() {
    super.initState();
    _wire();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AndroidMonitorShell.instance.init());
    });
  }

  @override
  void didUpdateWidget(covariant AndroidMonitorShellBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _wire();
  }

  void _wire() {
    final shell = AndroidMonitorShell.instance;
    shell.stopMonitor = widget.stopMonitor;
    shell.onUserMessage = widget.onUserMessage;
  }

  @override
  Widget build(BuildContext context) {
    _wire();
    return widget.child;
  }
}
