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
  final _lastNoticeKeys = <String, String>{};
  VoidCallback? stopMonitor;
  void Function(String message)? onUserMessage;
  void Function(Map<String, dynamic> event)? onForegroundNotice;

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
    PlatformHooks.onRollcallsDiscovered = (items) =>
        notifyRollcallsDiscovered(items.length);
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
      final accountKey =
          '${snapshot['ownerUserId'] ?? snapshot['userId'] ?? 0}_${snapshot['assistUserId'] ?? 'owner'}';
      if (snapshot['running'] == true) {
        _lastNoticeKeys.remove(accountKey);
      }
      final noticeKey = '${snapshot['runId']}:${snapshot['reason']}';
      if (snapshot['running'] == false && snapshot['reason'] != 'user_stop') {
        if (noticeKey != _lastNoticeKeys[accountKey]) {
          _lastNoticeKeys[accountKey] = noticeKey;
          onUserMessage?.call(snapshot['message'] as String? ?? '检测已停止');
        }
      }
    } else if (data['action'] == 'diagnostic_sent') {
      onUserMessage?.call('后台通知测试已发送');
    } else if (data['action'] == 'foreground_notice') {
      unawaited(_showForegroundNotice(data));
    }
  }

  Future<void> _showForegroundNotice(Map data) async {
    try {
      final run = await AndroidMonitorStore.readRun(
        runId: data['runId'] as String?,
      );
      if (run == null || run.id != data['runId']) return;
      final owner = await _secure.read(SecureStore.keyUserId);
      if (owner != '${run.ownerUserId}') return;
      if (onForegroundNotice != null) {
        onForegroundNotice!.call({
          for (final entry in data.entries) '${entry.key}': entry.value,
          'assistUserId': run.assistUserId,
          'ownerUserId': run.ownerUserId,
        });
        return;
      }
      onUserMessage?.call(data['message'] as String? ?? '发现新的签到');
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'monitor_foreground_notice',
      );
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

  Future<AndroidMonitorRun?> _accountRun(
    int? assistUserId, {
    int? ownerUserId,
  }) async {
    final runs = await AndroidMonitorStore.readRuns();
    for (final run in runs) {
      if (run.diagnosticOnly || run.assistUserId != assistUserId) continue;
      if (ownerUserId != null && run.ownerUserId != ownerUserId) continue;
      return run;
    }
    return null;
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
    final existing = await AndroidMonitorStore.readRuns();
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
    // Publish the new run before revoking older runs so the FGS never sees
    // an empty roster and shuts down during replacement.
    await AndroidMonitorStore.writeRun(run);
    for (final previous in existing) {
      if (previous.ownerUserId != run.ownerUserId ||
          previous.diagnosticOnly ||
          previous.assistUserId == assistUserId) {
        await _stopAccountRun(previous, 'replaced');
      }
    }
    return await _startRun(run) ? run.id : null;
  });

  Future<bool> _startRun(
    AndroidMonitorRun run, {
    Duration? diagnosticDelay,
  }) async {
    try {
      await AndroidMonitorStore.writeRun(run);
      if (diagnosticDelay != null) await _writeDiagnostic(run, diagnosticDelay);
      if (await FlutterForegroundTask.isRunningService) {
        FlutterForegroundTask.sendDataToTask({'action': 'runs_changed'});
        AppLog.event('shell.android_fgs_reuse', fields: {'runId': run.id});
        return true;
      }
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
      await _stopAccountRun(run, 'start_failed');
      return false;
    }
  }

  Future<void> stopAccount({int? assistUserId, String reason = 'user_stop'}) =>
      _serial(() async {
        final runs = await AndroidMonitorStore.readRuns();
        var stopped = false;
        for (final run in runs) {
          if (!run.diagnosticOnly && run.assistUserId == assistUserId) {
            await _stopAccountRun(run, reason);
            stopped = true;
          }
        }
        if (!stopped) return;
        final remaining = await AndroidMonitorStore.readRuns();
        if (remaining.isEmpty) {
          if (await FlutterForegroundTask.isRunningService) {
            final result = await FlutterForegroundTask.stopService();
            if (result is ServiceRequestFailure) throw result.error;
          }
        } else {
          FlutterForegroundTask.sendDataToTask({'action': 'runs_changed'});
        }
      });

  Future<void> stopOngoing({String reason = 'user_stop'}) =>
      _serial(() => _stopRun(reason));

  Future<void> _stopAccountRun(AndroidMonitorRun run, String reason) async {
    // Revoke durable authorization before writing the stopped snapshot.
    await AndroidMonitorStore.clearRun(runId: run.id);
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
      'attendanceInterval': run.config.effectiveAttendanceIntervalSeconds,
      'completeProbe': run.config.completeProbe,
      'reason': reason,
      'message': '检测已停止',
      'nextPollAtMs': null,
      'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
    });
    await _secure.delete(run.credentialKey);
    AppLog.event(
      'shell.android_fgs_stop',
      fields: {'runId': run.id, 'reason': reason},
    );
  }

  Future<void> _stopRun(String reason) async {
    final runs = await AndroidMonitorStore.readRuns();
    for (final run in runs) {
      await _stopAccountRun(run, reason);
    }
    await AndroidMonitorStore.clearRun();
    if (await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.stopService();
      if (result is ServiceRequestFailure) throw result.error;
    }
  }

  Future<void> updateConfig(MonitorConfig config, {int? assistUserId}) =>
      _serial(() async {
        final run = await _accountRun(assistUserId);
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
        FlutterForegroundTask.sendDataToTask({
          'action': 'config',
          'runId': run.id,
        });
      });

  Future<void> pollNow({int? assistUserId, bool manual = true}) async {
    final run = await _accountRun(assistUserId);
    if (run != null) {
      FlutterForegroundTask.sendDataToTask({
        'action': 'poll_now',
        'manual': manual,
        'runId': run.id,
      });
    }
  }

  Future<Map<String, dynamic>?> readStatus({int? assistUserId}) async {
    await init();
    final ownerStr = await _secure.read(SecureStore.keyUserId);
    final ownerId = int.tryParse(ownerStr ?? '');
    final run = await _accountRun(assistUserId, ownerUserId: ownerId);
    if (run != null && await FlutterForegroundTask.isRunningService) {
      final snapshot = await AndroidMonitorStore.readSnapshot(runId: run.id);
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
        'attendanceInterval': run.config.effectiveAttendanceIntervalSeconds,
      };
    }
    final snapshot = ownerId != null
        ? await AndroidMonitorStore.readAccountSnapshot(ownerId, assistUserId)
        : (run != null
              ? await AndroidMonitorStore.readSnapshot(runId: run.id)
              : await AndroidMonitorStore.readSnapshot());
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
      final scopes = <int?>{
        null,
        for (final run in await AndroidMonitorStore.readRuns())
          if (!run.diagnosticOnly) run.assistUserId,
      };
      for (final scope in scopes) {
        final status = await readStatus(assistUserId: scope);
        if (status != null) _onTaskData(status);
      }
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
      enabled == false || channel?.importance == Importance.none;

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
    this.onForegroundNotice,
    required this.child,
  });
  final VoidCallback stopMonitor;
  final void Function(String message) onUserMessage;
  final void Function(Map<String, dynamic> event)? onForegroundNotice;
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
    AndroidMonitorShell.instance.onForegroundNotice = widget.onForegroundNotice;
  }

  @override
  void dispose() {
    AndroidMonitorShell.instance.stopMonitor = null;
    AndroidMonitorShell.instance.onUserMessage = null;
    AndroidMonitorShell.instance.onForegroundNotice = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
