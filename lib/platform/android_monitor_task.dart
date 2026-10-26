import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/ndjson_file_sink.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/monitor/monitor_engine.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/monitor/automatic_rollcall_answer.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/platform/android_monitor_notifications.dart';
import 'package:xmu_rollcall/platform/android_monitor_platform.dart';
import 'package:xmu_rollcall/platform/android_monitor_store.dart';
import 'package:xmu_rollcall/features/location/course_radar_store.dart';

String formatMonitorCountdown(DateTime? nextPollAt, {DateTime? now}) {
  final secs = nextPollAt?.difference(now ?? DateTime.now()).inSeconds ?? 0;
  if (secs <= 0) return '即将检测';
  final m = secs ~/ 60;
  final s = secs % 60;
  if (m <= 0) return '下次检测约 ${s}s';
  return '下次检测约 $m:${s.toString().padLeft(2, '0')}';
}

@pragma('vm:entry-point')
void androidMonitorTaskCallback() {
  FlutterForegroundTask.setTaskHandler(AndroidMonitorTaskHandler());
}

/// Owns polling, alerts and status independently of the UI engine.
class AndroidMonitorTaskHandler extends TaskHandler {
  final _notifications = AndroidMonitorNotifications();
  final _secure = SecureStore();
  AndroidMonitorRun? _run;
  MonitorEngine? _engine;
  TronHttpClient? _client;
  Map<String, dynamic> _snapshot = {};
  Future<void> _writes = Future.value();
  bool _destroyed = false;
  bool _cycleBusy = false;
  bool _shuttingDown = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    DartPluginRegistrant.ensureInitialized();
    try {
      final support = await getApplicationSupportDirectory();
      await AppLog.bootstrap(
        sink: NdjsonFileSink(
          logsDir: Directory('${support.path}/monitor-logs'),
        ),
      );
      _run = await AndroidMonitorStore.readRun();
      final run = _run;
      if (run == null) {
        await FlutterForegroundTask.stopService();
        return;
      }
      await _notifications.init();
      final previous = await AndroidMonitorStore.readSnapshot();
      final notified = previous?['runId'] == run.id
          ? (previous?['notifiedIds'] as List? ?? []).whereType<int>().toSet()
          : <int>{};
      _snapshot = {
        'action': 'snapshot',
        'runId': run.id,
        'userId': run.userId,
        'ownerUserId': run.ownerUserId,
        'assistUserId': run.assistUserId,
        'running': true,
        'diagnosticOnly': run.diagnosticOnly,
        'failures': 0,
        'notifiedIds': notified.toList(),
        'updatedAtMs': previous?['runId'] == run.id
            ? (previous?['updatedAtMs'] ?? 0)
            : 0,
        'message': run.diagnosticOnly ? '后台通知测试等待中' : '后台检测已启动',
      };
      _publish();
      AppLog.event(
        'monitor.service.start',
        fields: {
          'runId': run.id,
          'userId': run.userId,
          'ownerUserId': run.ownerUserId,
          'assistUserId': run.assistUserId,
          'starter': starter.name,
          'diagnosticOnly': run.diagnosticOnly,
        },
      );
      if (!run.diagnosticOnly) {
        final raw = await _secure.read(run.credentialKey);
        if (raw == null) throw StateError('Missing monitor credential');
        final credential = jsonDecode(raw) as Map;
        if (credential['userId'] != run.userId) {
          throw StateError('Wrong monitor account');
        }
        // Independent memory jar: never race the UI's persistent cookies.
        final memory = SecureStore.memory({
          SecureStore.keySessionCookies: credential['cookies'] as String,
          SecureStore.keyDeviceId: credential['deviceId'] as String,
        });
        final client = TronHttpClient(store: memory, cookieJar: CookieJar());
        _client = client;
        await client.init();
        await _requireCurrentAccount();
        final repo = RollcallRepository(
          loadDetectionWindow: () => DetectionWindow.read(reload: true),
          http: client,
          identity: DeviceIdentity(memory),
        );
        final automatic = AutomaticRollcallAnswer(
          repository: repo,
          runId: run.id,
          onRadarSuccess: (point) async {
            await _requireCurrentAccount();
            await persistMeetingRadarPoint(
              run.ownerUserId,
              run.assistUserId,
              point,
            );
          },
          radarLocation: createAutomaticRadarLocationReader(
            ownerId: run.ownerUserId,
            assistUserId: run.assistUserId,
          ),
          onAnswered: (item, result) async {
            await _requireCurrentAccount();
            await _notifications.showResult(
              runId: run.id,
              courseTitle: item.courseTitle,
              ok: result.ok,
              requireCurrent: _requireCurrentAccount,
            );
          },
          requireCurrent: () async {
            await _requireCurrentAccount();
            final current = await AndroidMonitorStore.readRun();
            if (current?.config.autoAnswer != true) {
              throw StateError('Automatic answering disabled');
            }
          },
        );
        _engine = MonitorEngine(
          config: run.config,
          loadDetectionWindow: () => DetectionWindow.read(reload: true),
          processAutomatic: automatic.process,
          completedAutomaticIds: () => automatic.completedIds,
          automaticNumberCodes: () => automatic.numberCodes,
          notifiedIds: notified,
          fetch: () async {
            await _requireCurrentAccount();
            try {
              // Discovery must not wait for number-code enrichment.
              final items = await repo.fetchActive();
              await _requireCurrentAccount();
              return items;
            } on DioException catch (error) {
              if (error.response?.statusCode == 401 ||
                  error.response?.statusCode == 403) {
                await _shutdown('session_expired', '登录已失效，请重新登录后开始检测');
              }
              rethrow;
            }
          },
          notify: (items) async {
            await _requireCurrentAccount();
            try {
              await _notifications.discovered(
                runId: run.id,
                count: items.length,
                courseTitle: items.first.courseTitle,
                requireCurrent: _requireCurrentAccount,
              );
              AppLog.event(
                'monitor.notification.sent',
                fields: {'runId': run.id, 'count': items.length},
              );
              return true;
            } catch (error, stack) {
              AppLog.logAppError(
                error: error,
                stackTrace: stack,
                source: 'monitor_notification',
              );
              return false;
            }
          },
          onUpdate: _onEngineUpdate,
        )..start();
      }
      await _cycle();
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'monitor_service_start',
      );
      await _shutdown('initialization_failed', '后台检测初始化失败，请重新开始');
    }
  }

  Future<void> _requireCurrentAccount() async {
    if (_destroyed || _shuttingDown) throw StateError('Monitor has stopped');
    final current = await AndroidMonitorStore.readRun();
    final owner = await _secure.read(SecureStore.keyUserId);
    if (_destroyed ||
        current?.id != _run?.id ||
        owner != '${_run?.ownerUserId}') {
      await _shutdown('account_changed', '账号已退出或切换，检测已停止');
      throw StateError('Monitor account changed');
    }
  }

  void _onEngineUpdate(MonitorEngineUpdate update) {
    if (_destroyed || _shuttingDown) return;
    if (update.sessionExpired) {
      unawaited(_shutdown('session_expired', '登录已失效，请重新登录后开始检测'));
      return;
    }
    _snapshot['failures'] = update.failures;
    if (update.nextPollAt != null) {
      _snapshot['nextPollAtMs'] = update.nextPollAt!.millisecondsSinceEpoch;
    }
    if (update.lastPollAt != null) {
      if (update.ok == true) {
        _snapshot['lastSuccessfulPollAtMs'] =
            update.lastPollAt!.millisecondsSinceEpoch;
      }
      _snapshot.addAll({
        'lastPollAtMs': update.lastPollAt!.millisecondsSinceEpoch,
        'ok': update.ok,
        'count': update.count ?? 0,
        'message': update.message,
        'notifiedIds': _engine!.notifiedIds.toList(),
      });
      AppLog.event(
        'monitor.poll',
        level: update.ok == true ? 'I' : 'W',
        fields: {
          'runId': _run?.id,
          'ok': update.ok,
          'count': update.count ?? 0,
          'failures': update.failures,
        },
      );
    }
    if (update.items != null) {
      _snapshot['items'] = [
        for (final item in update.items!) item.toMonitorJson(),
      ];
    }
    if (update.message != null) _snapshot['message'] = update.message;
    _publish();
  }

  void _publish() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final previous = _snapshot['updatedAtMs'] as int? ?? 0;
    _snapshot['updatedAtMs'] = now > previous ? now : previous + 1;
    final data = Map<String, dynamic>.from(_snapshot);
    _writes = _writes
        .then((_) async {
          final current = await AndroidMonitorStore.readRun();
          if (current != null && current.id != data['runId']) return;
          await AndroidMonitorStore.writeSnapshot(data);
          FlutterForegroundTask.sendDataToMain(data);
        })
        .catchError((Object error, StackTrace stack) {
          AppLog.logAppError(
            error: error,
            stackTrace: stack,
            source: 'monitor_snapshot',
          );
        });
  }

  @override
  void onRepeatEvent(DateTime timestamp) => unawaited(_cycle());

  Future<void> _cycle() async {
    if (_cycleBusy || _destroyed || _shuttingDown) return;
    _cycleBusy = true;
    try {
      final run = await AndroidMonitorStore.readRun();
      if (run == null || run.id != _run?.id) {
        await _shutdown('cancelled', '检测已停止');
        return;
      }
      if (jsonEncode(run.toJson()) != jsonEncode(_run!.toJson())) {
        _engine?.updateConfig(run.config);
      }
      _run = run;
      _snapshot.addAll({
        'autoAnswer': run.config.autoAnswer,
        'answerWaitMode': run.config.answerWaitMode.index,
        'answerWaitCount': run.config.answerWaitCount,
        'answerWaitPercent': run.config.answerWaitPercent,
        'attendanceInterval': run.config.effectiveAttendanceIntervalSeconds,
      });
      final diagnostic = await AndroidMonitorStore.readDiagnostic();
      if (run.diagnosticOnly && diagnostic?['runId'] != run.id) {
        await _shutdown('diagnostic_expired', '通知测试已过期，请重新测试');
        return;
      }
      if (diagnostic?['runId'] == run.id &&
          DateTime.now().millisecondsSinceEpoch >=
              (diagnostic!['atMs'] as int)) {
        final expiresAt = diagnostic['expiresAtMs'] as int?;
        if (expiresAt == null ||
            DateTime.now().millisecondsSinceEpoch > expiresAt) {
          await FlutterForegroundTask.removeData(
            key: AndroidMonitorStore.diagnosticKey,
          );
          if (run.diagnosticOnly) {
            await _shutdown('diagnostic_expired', '通知测试已过期，请重新测试');
          }
          return;
        }
        await _notifications.show(count: 1, diagnostic: true);
        await FlutterForegroundTask.removeData(
          key: AndroidMonitorStore.diagnosticKey,
        );
        AppLog.event('monitor.diagnostic.sent', fields: {'runId': run.id});
        if (run.diagnosticOnly) {
          await _shutdown('diagnostic_complete', '后台通知测试已完成');
          return;
        }
        FlutterForegroundTask.sendDataToMain({
          'action': 'diagnostic_sent',
          'runId': run.id,
        });
      }
      final ms = _snapshot['nextPollAtMs'] as int?;
      final failures = _snapshot['failures'] as int? ?? 0;
      final text = run.diagnosticOnly
          ? '后台通知测试等待中'
          : failures > 0
          ? '检测失败 $failures 次，等待重试'
          : '下次检测倒计时  发现签到后另发提醒';
      await AndroidMonitorPlatform.updateCountdown(
        title: run.diagnosticOnly ? '厦大签到  后台测试' : '厦大签到检测中',
        text: text,
        deadlineMs: run.diagnosticOnly ? (diagnostic?['atMs'] as int?) : ms,
      );
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'monitor_service_cycle',
      );
    } finally {
      _cycleBusy = false;
    }
  }

  Future<void> _shutdown(String reason, String message) async {
    if (_shuttingDown || _destroyed) return;
    _shuttingDown = true;
    _engine?.stop();
    _client?.dio.close(force: true);
    _snapshot.addAll({
      'running': false,
      'reason': reason,
      'message': message,
      'nextPollAtMs': null,
    });
    _publish();
    await _writes;
    if ((await AndroidMonitorStore.readRun())?.id == _run?.id) {
      await AndroidMonitorStore.clearRun();
      final run = _run;
      if (run != null) await _secure.delete(run.credentialKey);
    }
    AppLog.event(
      'monitor.service.stop',
      fields: {'runId': _run?.id, 'reason': reason},
    );
    await AppLog.flush();
    final current = await AndroidMonitorStore.readRun();
    if (current != null && current.id != _run?.id) return;
    await FlutterForegroundTask.stopService();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _destroyed = true;
    _engine?.stop();
    _client?.dio.close(force: true);
    if (isTimeout) {
      _snapshot.addAll({
        'running': false,
        'reason': 'timeout',
        'message': '后台检测已达系统时限，已停止',
        'nextPollAtMs': null,
      });
      _publish();
      await _writes;
      final run = _run;
      if (run != null && (await AndroidMonitorStore.readRun())?.id == run.id) {
        await AndroidMonitorStore.clearRun();
        await _secure.delete(run.credentialKey);
      }
    }
    AppLog.event(
      'monitor.service.destroy',
      fields: {'runId': _run?.id, 'timeout': isTimeout},
    );
    await AppLog.flush();
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map || data['runId'] != _run?.id) return;
    if (data['action'] == 'poll_now') {
      unawaited(_engine?.pollNow() ?? Future.value());
    }
    if (data['action'] == 'sync') {
      FlutterForegroundTask.sendDataToMain(
        Map<String, dynamic>.from(_snapshot),
      );
    }
    if (data['action'] == 'config' || data['action'] == 'diagnostic') {
      unawaited(_cycle());
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') unawaited(_shutdown('user_stop', '检测已停止'));
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp('/');

  @override
  void onNotificationDismissed() {
    AppLog.event('monitor.notification.dismissed', fields: {'runId': _run?.id});
    unawaited(_restoreNotification());
  }

  Future<void> _restoreNotification() async {
    if (_destroyed || _shuttingDown) return;
    if ((await AndroidMonitorStore.readRun())?.id != _run?.id) return;
    final result = await FlutterForegroundTask.updateService();
    if (result is ServiceRequestFailure) {
      AppLog.logAppError(
        error: result.error,
        source: 'monitor_notification_restore',
      );
    }
    // The service restores the notice asynchronously; the next cycle decorates it.
  }
}
