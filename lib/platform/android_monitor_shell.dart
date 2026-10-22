import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import 'package:xmu_rollcall/app/shell_navigation.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/platform/android_monitor_notifications.dart';
import 'package:xmu_rollcall/platform/android_monitor_platform.dart';
import 'package:xmu_rollcall/platform/android_monitor_store.dart';
import 'package:xmu_rollcall/platform/android_monitor_task.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

class AndroidMonitorShell {
  AndroidMonitorShell._();
  static final instance = AndroidMonitorShell._();
  final _notifications = AndroidMonitorNotifications();
  final _secure = SecureStore();
  final _listeners = <void Function(Map<String, dynamic>)>{};
  Future<void>? _initializing;
  Future<void> _commands = Future.value();
  bool _ready = false;
  AppLifecycleListener? _lifecycle;
  String? _lastNoticeKey;
  VoidCallback? stopMonitor;
  void Function(String message)? onUserMessage;

  void addListener(void Function(Map<String, dynamic>) listener) =>
      _listeners.add(listener);
  void removeListener(void Function(Map<String, dynamic>) listener) =>
      _listeners.remove(listener);

  Future<void> init() {
    if (!PlatformHooks.isAndroid || _ready) return Future.value();
    return _initializing ??= _init().whenComplete(() => _initializing = null);
  }

  Future<void> _init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: AndroidMonitorPlatform.ongoingChannelId,
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
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
    await _notifications.init(onResponse: _onNotificationResponse);
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _lifecycle ??= AppLifecycleListener(
      onResume: () => unawaited(_restoreStatus()),
    );
    PlatformHooks.onRollcallsDiscovered = notifyRollcallsDiscovered;
    _ready = true;
    AppLog.event('shell.android_ready', fields: {'ok': true});
    final launch = await _notifications.plugin
        .getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse?.payload ==
            AndroidMonitorNotifications.discoveryPayload) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ShellNavigation.instance.openRollcall(popToRoot: true),
      );
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    if (response.payload == AndroidMonitorNotifications.discoveryPayload) {
      ShellNavigation.instance.openRollcall(popToRoot: true);
    }
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    if (data['action'] == 'snapshot') {
      final snapshot = Map<String, dynamic>.from(data);
      for (final listener in [..._listeners]) {
        listener(snapshot);
      }
      if (snapshot['running'] == true) _lastNoticeKey = null;
      final noticeKey = '${snapshot['runId']}:${snapshot['reason']}';
      if (snapshot['running'] == false && snapshot['reason'] != 'user_stop') {
        if (noticeKey != _lastNoticeKey) {
          _lastNoticeKey = noticeKey;
          onUserMessage?.call(snapshot['message'] as String? ?? '检测已停止');
        }
      }
    } else if (data['action'] == 'diagnostic_sent') {
      onUserMessage?.call('后台通知测试已发送');
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _commands = _commands.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<bool> prepareStart() async {
    if (!PlatformHooks.isAndroid) return true;
    await init();
    if (await FlutterForegroundTask.checkNotificationPermission() ==
        NotificationPermission.granted) {
      return true;
    }
    return await FlutterForegroundTask.requestNotificationPermission() ==
        NotificationPermission.granted;
  }

  Future<String?> startMonitor({
    required int userId,
    int? ownerUserId,
    int? assistUserId,
    required MonitorConfig config,
    required String cookies,
    required String deviceId,
    required String runId,
  }) => _serial(() async {
    await init();
    await _stopRun('replaced');
    final run = AndroidMonitorRun(
      id: runId,
      userId: userId,
      ownerUserId: ownerUserId,
      assistUserId: assistUserId,
      config: config,
    );
    await _secure.write(
      run.credentialKey,
      jsonEncode({'userId': userId, 'cookies': cookies, 'deviceId': deviceId}),
    );
    return await _startRun(run) ? run.id : null;
  });

  Future<bool> _startRun(
    AndroidMonitorRun run, {
    Duration? diagnosticDelay,
  }) async {
    try {
      await AndroidMonitorStore.writeRun(run);
      if (diagnosticDelay != null) await _writeDiagnostic(run, diagnosticDelay);
      final result = await FlutterForegroundTask.startService(
        serviceId: 2601,
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: run.diagnosticOnly ? '厦大签到  后台测试' : '厦大签到检测中',
        notificationText: run.diagnosticOnly ? '等待发送测试通知' : '正在开始检测',
        notificationButtons: const [NotificationButton(id: 'stop', text: '停止')],
        callback: androidMonitorTaskCallback,
      );
      if (result is ServiceRequestFailure) throw result.error;
      AppLog.event('shell.android_fgs_start', fields: {'runId': run.id});
      return true;
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'android_fgs_start',
      );
      await _stopRun('start_failed');
      await _secure.delete(run.credentialKey);
      return false;
    }
  }

  Future<void> stopOngoing({String reason = 'user_stop'}) =>
      _serial(() => _stopRun(reason));

  Future<void> _stopRun(String reason) async {
    final run = await AndroidMonitorStore.readRun();
    // Revoke durable authorization before stopping the service.
    await AndroidMonitorStore.clearRun();
    if (run != null) {
      await AndroidMonitorStore.writeSnapshot({
        'action': 'snapshot',
        'runId': run.id,
        'userId': run.userId,
        'ownerUserId': run.ownerUserId,
        'assistUserId': run.assistUserId,
        'running': false,
        'diagnosticOnly': run.diagnosticOnly,
        'autoAnswer': run.config.autoAnswer,
        'answerWaitMode': run.config.answerWaitMode.index,
        'answerWaitCount': run.config.answerWaitCount,
        'answerWaitPercent': run.config.answerWaitPercent,
        'reason': reason,
        'message': '检测已停止',
        'nextPollAtMs': null,
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
      });
      await _secure.delete(run.credentialKey);
    }
    if (await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.stopService();
      if (result is ServiceRequestFailure) throw result.error;
    }
    if (run != null) {
      AppLog.event(
        'shell.android_fgs_stop',
        fields: {'runId': run.id, 'reason': reason},
      );
    }
  }

  Future<void> updateConfig(MonitorConfig config) => _serial(() async {
    final run = await AndroidMonitorStore.readRun();
    if (run == null || run.diagnosticOnly) return;
    await AndroidMonitorStore.writeRun(
      AndroidMonitorRun(
        id: run.id,
        userId: run.userId,
        ownerUserId: run.ownerUserId,
        assistUserId: run.assistUserId,
        config: config,
      ),
    );
    FlutterForegroundTask.sendDataToTask({'action': 'config', 'runId': run.id});
  });

  Future<void> pollNow() async {
    final run = await AndroidMonitorStore.readRun();
    if (run != null) {
      FlutterForegroundTask.sendDataToTask({
        'action': 'poll_now',
        'runId': run.id,
      });
    }
  }

  Future<Map<String, dynamic>?> readStatus() async {
    await init();
    final snapshot = await AndroidMonitorStore.readSnapshot();
    final run = await AndroidMonitorStore.readRun();
    if (run != null && await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'action': 'sync', 'runId': run.id});
      return {
        if (snapshot?['runId'] == run.id) ...snapshot!,
        'action': 'snapshot',
        'runId': run.id,
        'userId': run.userId,
        'ownerUserId': run.ownerUserId,
        'assistUserId': run.assistUserId,
        'running': snapshot?['runId'] == run.id
            ? (snapshot?['running'] ?? true)
            : true,
        'diagnosticOnly': run.diagnosticOnly,
        'autoAnswer': run.config.autoAnswer,
        'answerWaitMode': run.config.answerWaitMode.index,
        'answerWaitCount': run.config.answerWaitCount,
        'answerWaitPercent': run.config.answerWaitPercent,
      };
    }
    if (snapshot == null) return null;
    return {
      ...snapshot,
      'running': false,
      'nextPollAtMs': null,
      if (snapshot['running'] == true) 'message': '后台服务已退出，请重新开始检测',
      if (snapshot['running'] == true) 'reason': 'service_missing',
      if (snapshot['running'] == true)
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<void> _restoreStatus() async {
    try {
      final status = await readStatus();
      if (status != null) _onTaskData(status);
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'android_monitor_restore',
      );
    }
  }

  Future<bool> testNotification() async {
    if (!await prepareStart()) return false;
    try {
      await _notifications.show(count: 1, diagnostic: true);
      AppLog.event('shell.android_notification_test', fields: {'ok': true});
      return true;
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'android_notification_test',
      );
      return false;
    }
  }

  Future<bool> scheduleDiagnostic(Duration delay) async {
    if (delay < const Duration(seconds: 15) ||
        delay > const Duration(minutes: 2) ||
        !await prepareStart()) {
      return false;
    }
    return _serial(() async {
      final existing = await AndroidMonitorStore.readRun();
      if (existing != null && await FlutterForegroundTask.isRunningService) {
        await _writeDiagnostic(existing, delay);
        FlutterForegroundTask.sendDataToTask({
          'action': 'diagnostic',
          'runId': existing.id,
        });
        return true;
      }
      await _stopRun('diagnostic_replaced');
      return _startRun(
        AndroidMonitorRun(
          id: const Uuid().v4(),
          userId: 0,
          config: const MonitorConfig(),
          diagnosticOnly: true,
        ),
        diagnosticDelay: delay,
      );
    });
  }

  Future<void> _writeDiagnostic(AndroidMonitorRun run, Duration delay) =>
      AndroidMonitorStore.writeDiagnostic({
        'runId': run.id,
        'atMs': DateTime.now().add(delay).millisecondsSinceEpoch,
        'expiresAtMs': DateTime.now()
            .add(delay + const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      });

  Future<void> notifyRollcallsDiscovered(int count) async {
    if (count > 0) await _notifications.show(count: count);
  }

  Future<void> openBatteryOptimizationSettings() =>
      FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();

  Future<AndroidDiscoveryNotificationStatus> readNotificationSettings() async {
    await init();
    final android = _notifications.plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final enabled = await android?.areNotificationsEnabled();
    final channels = await android?.getNotificationChannels();
    AndroidNotificationChannel? discovery;
    AndroidNotificationChannel? ongoing;
    for (final channel in channels ?? <AndroidNotificationChannel>[]) {
      if (channel.id == AndroidMonitorNotifications.discoveryChannelId) {
        discovery = channel;
      }
      if (channel.id == AndroidMonitorPlatform.ongoingChannelId) {
        ongoing = channel;
      }
    }
    return AndroidDiscoveryNotificationStatus(
      enabled: enabled,
      channel: discovery,
      ongoingChannel: ongoing,
      background: await AndroidMonitorPlatform.backgroundSettings(),
    );
  }

  Future<void> openDiscoveryNotificationSettings() async {
    await init();
    await AndroidMonitorPlatform.openChannelSettings(
      AndroidMonitorNotifications.discoveryChannelId,
    );
  }

  Future<void> openOngoingNotificationSettings() =>
      AndroidMonitorPlatform.openChannelSettings(
        AndroidMonitorPlatform.ongoingChannelId,
      );

  Future<void> openAppNotificationSettings() =>
      AndroidMonitorPlatform.openChannelSettings(null);

  Future<void> openAppBackgroundSettings() =>
      AndroidMonitorPlatform.openAppDetails();
}

class AndroidDiscoveryNotificationStatus {
  const AndroidDiscoveryNotificationStatus({
    required this.enabled,
    this.channel,
    this.ongoingChannel,
    this.background = const {},
  });
  final bool? enabled;
  final AndroidNotificationChannel? channel;
  final AndroidNotificationChannel? ongoingChannel;
  final Map<String, dynamic> background;

  bool get discoveryBlocked =>
      enabled == false ||
      (channel != null &&
          (channel!.importance.value < Importance.high.value ||
              !channel!.enableVibration));

  bool get ongoingAlerts =>
      ongoingChannel?.enableVibration == true ||
      ongoingChannel?.playSound == true;

  String get settingsFingerprint => [
    enabled,
    channel?.importance.value,
    channel?.enableVibration,
    channel?.playSound,
    ongoingChannel?.enableVibration,
    ongoingChannel?.playSound,
    background['manufacturer'],
    background['model'],
    background['sdkInt'],
    background['batteryExempt'],
  ].join('|');
}

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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(AndroidMonitorShell.instance.init()),
    );
  }

  @override
  void didUpdateWidget(covariant AndroidMonitorShellBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _wire();
  }

  void _wire() {
    AndroidMonitorShell.instance.stopMonitor = widget.stopMonitor;
    AndroidMonitorShell.instance.onUserMessage = widget.onUserMessage;
  }

  @override
  void dispose() {
    AndroidMonitorShell.instance.stopMonitor = null;
    AndroidMonitorShell.instance.onUserMessage = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
