import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_engine.dart';
import 'package:xmu_rollcall/features/monitor/automatic_rollcall_answer.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/platform/android_monitor_shell.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/features/location/course_radar_store.dart';

enum StartMonitorResult {
  started,
  alreadyRunning,
  notSignedIn,
  notificationDenied,
  fgsFailed,
  cancelled,
}

class MonitorState {
  const MonitorState({
    required this.config,
    this.running = false,
    this.starting = false,
    this.lastPollAt,
    this.lastSuccessfulPollAt,
    this.nextPollAt,
    this.logs = const [],
    this.consecutiveFailures = 0,
    this.loadingSettings = false,
  });
  final MonitorConfig config;
  final bool running;
  final bool starting;
  final bool loadingSettings;
  final DateTime? lastPollAt;
  final DateTime? lastSuccessfulPollAt;
  final DateTime? nextPollAt;
  final List<PollLogEntry> logs;
  final int consecutiveFailures;
  MonitorState copyWith({
    MonitorConfig? config,
    bool? running,
    bool? starting,
    bool? loadingSettings,
    DateTime? lastPollAt,
    DateTime? lastSuccessfulPollAt,
    DateTime? nextPollAt,
    List<PollLogEntry>? logs,
    int? consecutiveFailures,
    bool clearNext = false,
  }) => MonitorState(
    config: config ?? this.config,
    running: running ?? this.running,
    starting: starting ?? this.starting,
    loadingSettings: loadingSettings ?? this.loadingSettings,
    lastPollAt: lastPollAt ?? this.lastPollAt,
    lastSuccessfulPollAt: lastSuccessfulPollAt ?? this.lastSuccessfulPollAt,
    nextPollAt: clearNext ? null : nextPollAt ?? this.nextPollAt,
    logs: logs ?? this.logs,
    consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
  );
}

final monitorControllerProvider =
    StateNotifierProvider<MonitorController, MonitorState>(
      (ref) => MonitorController(ref),
    );

class MonitorController extends StateNotifier<MonitorState> {
  MonitorController(this._ref)
    : super(
        const MonitorState(config: MonitorConfig(), loadingSettings: true),
      ) {
    if (PlatformHooks.isAndroid) {
      AndroidMonitorShell.instance.addListener(_onSnapshot);
    }
    _loaded = _load();
    _ref.listen(detectionWindowProvider, (previous, next) {
      if (previous == null || next == null || !state.running) return;
      if (PlatformHooks.isAndroid) {
        unawaited(AndroidMonitorShell.instance.pollNow());
      } else {
        unawaited(_engine?.pollNow());
      }
    });
    _ref.listen(selectedRollcallAccountProvider, (previous, next) {
      if (previous == next) return;
      _changeSelectedAccount(
        preserveBackgroundRun:
            _restoringAccountSelection ||
            _ref.read(selectedRollcallAccountProvider.notifier).restoring,
      );
    });
    _ref.listen(assistControllerProvider, (previous, next) {
      final scope = _ref.read(selectedRollcallAccountProvider);
      if (scope != null &&
          next.ready &&
          !next.identities.any((a) => a.userId == scope)) {
        _ref.read(selectedRollcallAccountProvider.notifier).state = null;
      }
    });
    _ref.listen(authControllerProvider, (previous, next) {
      if (previous?.isSignedIn == true &&
          (!next.isSignedIn || previous?.profile?.id != next.profile?.id)) {
        _changeSelectedAccount();
      } else if (next.isSignedIn && previous?.isSignedIn != true) {
        // A restored login is not a user-requested task stop. The persisted
        // Android run still validates the workspace login before each request.
        _generation++;
        _configKey = null;
        state = const MonitorState(
          config: MonitorConfig(),
          loadingSettings: true,
        );
        _loaded = _load();
      }
    });
  }
  final Ref _ref;
  late Future<void> _loaded;
  String? _configKey;
  int _configRevision = 0;
  Future<StartMonitorResult>? _startFuture;
  Future<void> _stopping = Future.value();
  MonitorEngine? _engine;
  Timer? _persistDebounce;
  Timer? _debugDiscoveryTimer;
  String? _runId;
  int _generation = 0;
  bool _restoring = false;
  bool _canRestoreAccountSelection = true;
  bool _restoringAccountSelection = false;
  int? _lastSnapshotPoll;
  int _lastSnapshotStamp = -1;

  void _changeSelectedAccount({bool preserveBackgroundRun = false}) {
    final config = state.config;
    final key = _configKey;
    _persistDebounce?.cancel();
    if (key != null) unawaited(_persistConfig(config, key));
    _configKey = null;
    if (preserveBackgroundRun) {
      _generation++;
    } else {
      _canRestoreAccountSelection = false;
      stop(reason: 'selected_account_changed');
    }
    _startFuture = null;
    _lastSnapshotPoll = null;
    _lastSnapshotStamp = -1;
    state = const MonitorState(config: MonitorConfig(), loadingSettings: true);
    _loaded = _load();
  }

  Future<void> _load() async {
    final revision = ++_configRevision;
    final scope = _ref.read(selectedRollcallAccountProvider);
    final ownerId = _ref.read(authControllerProvider).profile?.id ?? 0;
    final key = 'monitor_account_${ownerId}_${scope ?? ownerId}';
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || revision != _configRevision) return;
    _configKey = key;
    final legacyOwner = prefs.getInt('monitor_legacy_owner');
    final useLegacy =
        scope == null &&
        ownerId != 0 &&
        (legacyOwner == null || legacyOwner == ownerId);
    if (useLegacy && legacyOwner == null) {
      await prefs.setInt('monitor_legacy_owner', ownerId);
      if (!mounted || revision != _configRevision) return;
    }
    int? integer(String field) =>
        prefs.getInt('${key}_$field') ??
        (useLegacy ? prefs.getInt('monitor_$field') : null);
    final preset = MonitorPreset.values[(integer('preset') ?? 0).clamp(0, 2)];
    state = state.copyWith(
      loadingSettings: false,
      config: MonitorConfig(
        preset: preset,
        intervalSeconds: MonitorConfig.normalizeIntervalSeconds(
          integer('interval') ?? preset.defaultSeconds,
        ),
        jitterRatio:
            (prefs.getDouble('${key}_jitter') ??
                    (useLegacy ? prefs.getDouble('monitor_jitter') : null) ??
                    0.2)
                .clamp(0.0, 0.5),
        autoAnswer:
            prefs.getBool('${key}_auto_answer') ??
            (useLegacy ? prefs.getBool('monitor_auto_answer') : null) ??
            false,
        answerWaitMode: AnswerWaitMode
            .values[(integer('answer_wait_mode') ?? 2).clamp(0, 2)],
        answerWaitCount: (integer('answer_wait_count') ?? 10).clamp(1, 200),
        answerWaitPercent: (integer('answer_wait_percent') ?? 10).clamp(1, 100),
        attendanceIntervalSeconds: (integer('attendance_interval') ?? 20).clamp(
          15,
          120,
        ),
      ),
    );
    if (PlatformHooks.isAndroid) await _restore();
  }

  Future<void> _restore() async {
    final auth = _ref.read(authControllerProvider);
    if (!auth.isSignedIn) return;
    final canRestoreSelection = _canRestoreAccountSelection;
    _canRestoreAccountSelection = false;
    final generation = _generation;
    try {
      final snapshot = await AndroidMonitorShell.instance.readStatus();
      if (!mounted ||
          generation != _generation ||
          state.starting ||
          snapshot == null) {
        return;
      }
      final restoredScope = snapshot['assistUserId'];
      if (canRestoreSelection &&
          snapshot['running'] == true &&
          (snapshot['ownerUserId'] ?? snapshot['userId']) == auth.profile?.id &&
          _ref.read(selectedRollcallAccountProvider) == null &&
          restoredScope is int) {
        final service = await _ref.read(assistServiceProvider.future);
        final accounts = await service.listIdentities();
        if (!mounted || generation != _generation || state.starting) return;
        if (!accounts.any((a) => a.userId == restoredScope)) {
          await AndroidMonitorShell.instance.stopOngoing(
            reason: 'account_removed',
          );
          return;
        }
        // Hydrate the selected account without revoking its existing worker.
        // Explicit user switches always take the stopping path above.
        _restoringAccountSelection = true;
        try {
          _ref.read(selectedRollcallAccountProvider.notifier).state =
              restoredScope;
        } finally {
          _restoringAccountSelection = false;
        }
        return;
      }
      _restoring = true;
      _onSnapshot(snapshot);
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'monitor_restore',
      );
    } finally {
      _restoring = false;
    }
  }

  void _onSnapshot(Map<String, dynamic> data) {
    if (!mounted || data['diagnosticOnly'] == true) return;
    final auth = _ref.read(authControllerProvider);
    final scope = _ref.read(selectedRollcallAccountProvider);
    if (!auth.isSignedIn ||
        (data['ownerUserId'] ?? data['userId']) != auth.profile?.id ||
        data['assistUserId'] != scope) {
      return;
    }
    if (!_restoring && data['runId'] != _runId) return;
    if (data['runId'] != _runId) _lastSnapshotStamp = -1;
    final stamp = data['updatedAtMs'] as int? ?? 0;
    if (stamp <= _lastSnapshotStamp) return;
    _lastSnapshotStamp = stamp;
    _runId = data['runId'] as String?;
    final running = data['running'] == true;
    final lastMs = data['lastPollAtMs'] as int?;
    final successMs = data['lastSuccessfulPollAtMs'] as int?;
    final nextMs = data['nextPollAtMs'] as int?;
    final newPoll = lastMs != null && lastMs != _lastSnapshotPoll;
    final message = data['message'] as String?;
    final at = lastMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastMs);
    state = state.copyWith(
      running: running,
      starting: false,
      config: state.config.copyWith(
        enabled: running,
        autoAnswer: data['autoAnswer'] as bool?,
        answerWaitMode: data['answerWaitMode'] is int
            ? AnswerWaitMode.values[(data['answerWaitMode'] as int).clamp(0, 2)]
            : null,
        answerWaitCount: data['answerWaitCount'] as int?,
        answerWaitPercent: data['answerWaitPercent'] as int?,
        attendanceIntervalSeconds: data['attendanceInterval'] as int?,
      ),
      lastPollAt: at,
      lastSuccessfulPollAt: successMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(successMs),
      nextPollAt: nextMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(nextMs),
      clearNext: !running || nextMs == null,
      consecutiveFailures: data['failures'] as int? ?? 0,
      logs:
          newPoll ||
              (message != null && state.logs.firstOrNull?.message != message)
          ? [
              PollLogEntry(
                at: at ?? DateTime.now(),
                ok: data['ok'] != false,
                message: message ?? '检测状态已更新',
              ),
              ...state.logs,
            ].take(40).toList()
          : state.logs,
    );
    if (newPoll) {
      _lastSnapshotPoll = lastMs;
    }
    if (data['ok'] == true && data['items'] is List) {
      final items = (data['items'] as List)
          .map(
            (item) =>
                RollcallItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      _ref
          .read(
            activeRollcallsProvider(
              _ref.read(selectedRollcallAccountProvider),
            ).notifier,
          )
          .applyMonitorItems(
            items,
            fetchedAt: successMs == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(successMs),
          );
    }
    if (data['reason'] == 'session_expired' && scope == null) {
      _ref.read(authControllerProvider.notifier).expireSession();
    }
  }

  Future<void> _persistConfig(MonitorConfig config, String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${key}_preset', config.preset.index);
      await prefs.setInt('${key}_interval', config.effectiveIntervalSeconds);
      await prefs.setDouble('${key}_jitter', config.jitterRatio);
      await prefs.setBool('${key}_auto_answer', config.autoAnswer);
      await prefs.setInt(
        '${key}_attendance_interval',
        config.effectiveAttendanceIntervalSeconds,
      );
      await prefs.setInt(
        '${key}_answer_wait_mode',
        config.answerWaitMode.index,
      );
      await prefs.setInt('${key}_answer_wait_count', config.answerWaitCount);
      await prefs.setInt(
        '${key}_answer_wait_percent',
        config.answerWaitPercent,
      );
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'monitor_config',
      );
    }
  }

  void commitPersist() {
    _persistDebounce?.cancel();
    unawaited(_saveConfig());
  }

  Future<void> _saveConfig() async {
    if (state.loadingSettings) return;
    final key = _configKey;
    final config = state.config;
    final generation = _generation;
    try {
      if (!mounted || generation != _generation || key != _configKey) return;
      _engine?.updateConfig(config);
      if (PlatformHooks.isAndroid && state.running) {
        await AndroidMonitorShell.instance.updateConfig(config);
      }
      if (key != null) await _persistConfig(config, key);
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'monitor_config',
      );
    }
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 400), commitPersist);
  }

  void setPreset(MonitorPreset preset) {
    if (state.loadingSettings) return;
    state = state.copyWith(
      config: state.config.copyWith(
        preset: preset,
        intervalSeconds: preset == MonitorPreset.custom
            ? state.config.intervalSeconds
            : preset.defaultSeconds,
      ),
    );
    commitPersist();
  }

  void setIntervalSeconds(int seconds) {
    if (state.loadingSettings) return;
    state = state.copyWith(
      config: state.config.copyWith(
        preset: MonitorPreset.custom,
        intervalSeconds: MonitorConfig.normalizeIntervalSeconds(seconds),
      ),
    );
    _schedulePersist();
  }

  void setJitterRatio(double ratio) {
    if (state.loadingSettings) return;
    state = state.copyWith(
      config: state.config.copyWith(jitterRatio: ratio.clamp(0.0, 0.5)),
    );
    _schedulePersist();
  }

  void setAttendanceIntervalSeconds(int seconds) {
    if (state.loadingSettings) return;
    state = state.copyWith(
      config: state.config.copyWith(attendanceIntervalSeconds: seconds),
    );
    commitPersist();
  }

  void start() => unawaited(startAsync());

  void setAutomaticAnswer(bool value) {
    if (state.loadingSettings) return;
    state = state.copyWith(config: state.config.copyWith(autoAnswer: value));
    _engine?.updateConfig(state.config);
    commitPersist();
  }

  void setAnswerWaitMode(AnswerWaitMode mode) {
    if (state.loadingSettings) return;
    state = state.copyWith(config: state.config.copyWith(answerWaitMode: mode));
    _engine?.updateConfig(state.config);
    commitPersist();
  }

  void setAnswerWaitValue(int value) {
    if (state.loadingSettings) return;
    final c = state.config;
    state = state.copyWith(
      config: c.answerWaitMode == AnswerWaitMode.count
          ? c.copyWith(answerWaitCount: value)
          : c.copyWith(answerWaitPercent: value),
    );
    _engine?.updateConfig(state.config);
    _schedulePersist();
  }

  Future<StartMonitorResult> startAsync() {
    if (_startFuture != null) return _startFuture!;
    if (state.running) return Future.value(StartMonitorResult.alreadyRunning);
    final generation = ++_generation;
    state = state.copyWith(starting: true);
    late final Future<StartMonitorResult> operation;
    operation = _start(generation).whenComplete(() {
      if (identical(_startFuture, operation)) _startFuture = null;
    });
    return _startFuture = operation;
  }

  Future<StartMonitorResult> _start(int generation) async {
    bool current() => mounted && generation == _generation;
    try {
      await _loaded;
      await _stopping;
      if (!current()) return StartMonitorResult.cancelled;
      final auth = _ref.read(authControllerProvider);
      final userId = auth.profile?.id;
      if (!auth.isSignedIn || userId == null || userId == 0) {
        return StartMonitorResult.notSignedIn;
      }
      final scope = _ref.read(selectedRollcallAccountProvider);
      if (scope != null) {
        final account = _ref
            .read(assistControllerProvider)
            .identities
            .firstWhere((a) => a.userId == scope);
        final service = await _ref.read(assistServiceProvider.future);
        await service.ensureSession(account);
        if (!current()) return StartMonitorResult.cancelled;
      }
      if (PlatformHooks.isAndroid) {
        if (!await AndroidMonitorShell.instance.prepareStart()) {
          return StartMonitorResult.notificationDenied;
        }
        if (!current()) return StartMonitorResult.cancelled;
        final client = _ref
            .read(sessionClientRegistryProvider)
            .forKey(
              scope == null ? SessionKey.owner : SessionKey.assist(scope),
            );
        final cookies = await client.exportCookiesJson();
        final device = scope == null
            ? await _ref.read(deviceIdentityProvider).getId()
            : _ref
                  .read(assistControllerProvider)
                  .identities
                  .firstWhere((a) => a.userId == scope)
                  .deviceId;
        if (device == null || device.isEmpty) {
          return StartMonitorResult.notSignedIn;
        }
        if (!current()) return StartMonitorResult.cancelled;
        if (cookies == null ||
            _ref.read(authControllerProvider).profile?.id != userId) {
          return StartMonitorResult.notSignedIn;
        }
        final id = const Uuid().v4();
        _runId = id;
        _lastSnapshotPoll = null;
        _lastSnapshotStamp = -1;
        final startedId = await AndroidMonitorShell.instance.startMonitor(
          userId: scope ?? userId,
          ownerUserId: userId,
          assistUserId: scope,
          config: state.config,
          cookies: cookies,
          deviceId: device,
          runId: id,
        );
        if (!current()) return StartMonitorResult.cancelled;
        if (startedId == null) {
          _runId = null;
          state = state.copyWith(
            running: false,
            config: state.config.copyWith(enabled: false),
            clearNext: true,
          );
          return StartMonitorResult.fgsFailed;
        }
        final status = await AndroidMonitorShell.instance.readStatus();
        if (!current()) return StartMonitorResult.cancelled;
        if (status != null && status['runId'] == id) _onSnapshot(status);
        return state.running
            ? StartMonitorResult.started
            : StartMonitorResult.fgsFailed;
      }
      _engine?.stop();
      final desktopRunId = const Uuid().v4();
      final repo = _ref.read(
        scope == null
            ? rollcallRepositoryProvider
            : rollcallRepositoryForProvider(scope),
      );
      final automatic = AutomaticRollcallAnswer(
        repository: repo,
        runId: desktopRunId,
        onRadarSuccess: (point) async {
          if (current()) await persistMeetingRadarPoint(userId, scope, point);
        },
        radarLocation: createAutomaticRadarLocationReader(
          ownerId: userId,
          assistUserId: scope,
        ),
        requireCurrent: () async {
          final auth = _ref.read(authControllerProvider);
          if (!current() ||
              !auth.isSignedIn ||
              auth.profile?.id != userId ||
              _ref.read(selectedRollcallAccountProvider) != scope) {
            throw StateError('Account changed');
          }
        },
        onAnswered: (item, result) async {
          await _ref
              .read(_ref.read(localHistoryForProvider(scope)).notifier)
              .add(
                RollcallHistoryEntry(
                  rollcallId: item.rollcallId,
                  courseTitle: item.courseTitle,
                  typeLabel: '${item.typeLabel}（自动）',
                  ok: result.ok,
                  at: DateTime.now(),
                  detail: result.message,
                ),
              );
          if (current()) {
            await PlatformHooks.onAutomaticAnswerResult?.call(item, result.ok);
          }
        },
      );
      _engine = MonitorEngine(
        config: state.config,
        loadDetectionWindow: () async {
          await _ref.read(detectionWindowProvider.notifier).ready;
          return _ref.read(detectionWindowProvider)!;
        },
        fetch: () {
          AppLog.event(
            'monitor.discovery.start',
            fields: {
              'runId': desktopRunId,
              'intervalSeconds': state.config.effectiveIntervalSeconds,
              'jitterRatio': state.config.jitterRatio,
              'session': scope == null ? 'owner' : 'assist',
            },
          );
          return repo.fetchActive();
        },
        processAutomatic: automatic.process,
        completedAutomaticIds: () => automatic.completedIds,
        automaticNumberCodes: () => automatic.numberCodes,
        notify: (items) async {
          if (!current()) return false;
          final notify = PlatformHooks.onRollcallsDiscovered;
          if (notify == null && PlatformHooks.isDesktop) return false;
          if (notify != null) await notify(items);
          return true;
        },
        onUpdate: (update) {
          if (!current()) return;
          if (update.lastPollAt != null && update.ok != null) {
            AppLog.event(
              'monitor.discovery.result',
              fields: {
                'runId': desktopRunId,
                'ok': update.ok,
                'count': ?update.count,
                'failures': update.failures,
              },
            );
          }
          if (update.sessionExpired) {
            stop(reason: 'session_expired');
            state = state.copyWith(
              logs: [
                PollLogEntry(
                  at: DateTime.now(),
                  ok: false,
                  message: update.message!,
                ),
                ...state.logs,
              ].take(40).toList(),
            );
            if (scope == null) {
              _ref.read(authControllerProvider.notifier).expireSession();
            }
            return;
          }
          state = state.copyWith(
            nextPollAt: update.nextPollAt,
            lastPollAt: update.lastPollAt,
            lastSuccessfulPollAt: update.ok == true ? update.lastPollAt : null,
            consecutiveFailures: update.failures,
            logs: update.message == null
                ? state.logs
                : [
                    PollLogEntry(
                      at: update.lastPollAt ?? DateTime.now(),
                      ok: update.ok == true,
                      message: update.message!,
                    ),
                    ...state.logs,
                  ].take(40).toList(),
          );
          if (update.items != null) {
            _ref
                .read(
                  activeRollcallsProvider(
                    _ref.read(selectedRollcallAccountProvider),
                  ).notifier,
                )
                .applyMonitorItems(update.items!, fetchedAt: update.lastPollAt);
          }
        },
      );
      state = state.copyWith(
        running: true,
        config: state.config.copyWith(enabled: true),
        consecutiveFailures: 0,
      );
      _engine!.start();
      return StartMonitorResult.started;
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'monitor_start',
      );
      if (current()) {
        _runId = null;
        state = state.copyWith(
          running: false,
          config: state.config.copyWith(enabled: false),
          clearNext: true,
        );
      }
      return StartMonitorResult.fgsFailed;
    } finally {
      if (current()) state = state.copyWith(starting: false);
    }
  }

  void stop({String reason = 'user_stop'}) {
    _generation++;
    _runId = null;
    _engine?.stop();
    _engine = null;
    _debugDiscoveryTimer?.cancel();
    state = state.copyWith(
      running: false,
      starting: false,
      config: state.config.copyWith(enabled: false),
      clearNext: true,
    );
    AppLog.event('monitor.stop.request', fields: {'reason': reason});
    if (PlatformHooks.isAndroid) {
      _stopping = AndroidMonitorShell.instance
          .stopOngoing(reason: reason)
          .catchError((Object error, StackTrace stack) {
            AppLog.logAppError(
              error: error,
              stackTrace: stack,
              source: 'monitor_stop',
            );
          });
    }
  }

  void pollNow() {
    if (!state.running) return;
    if (PlatformHooks.isAndroid) {
      unawaited(AndroidMonitorShell.instance.pollNow());
    } else {
      unawaited(_engine?.pollNow() ?? Future.value());
    }
  }

  Future<void> stopAsync({String reason = 'user_stop'}) {
    stop(reason: reason);
    return _stopping;
  }

  void debugArmRunning() {
    if (!kDebugMode || PlatformHooks.isAndroid) return;
    state = state.copyWith(
      running: true,
      config: state.config.copyWith(enabled: true),
    );
  }

  void debugScheduleDiscovery({
    Duration delay = const Duration(seconds: 10),
    int count = 1,
  }) {
    if (!kDebugMode) return;
    if (PlatformHooks.isAndroid) {
      unawaited(AndroidMonitorShell.instance.scheduleDiagnostic(delay));
      return;
    }
    _debugDiscoveryTimer?.cancel();
    _debugDiscoveryTimer = Timer(delay, () async {
      final notify = PlatformHooks.onRollcallsDiscovered;
      if (notify != null && count > 0) {
        await notify([
          for (var i = 0; i < count; i++)
            RollcallItem.fromJson({
              'rollcall_id': -i - 1,
              'course_title': '示例课程（测试）',
              'is_radar': true,
            }),
        ]);
      }
    });
  }

  void debugCancelScheduledDiscovery() => _debugDiscoveryTimer?.cancel();

  @override
  void dispose() {
    _generation++;
    _persistDebounce?.cancel();
    _debugDiscoveryTimer?.cancel();
    _engine?.stop();
    if (PlatformHooks.isAndroid) {
      AndroidMonitorShell.instance.removeListener(_onSnapshot);
    }
    super.dispose();
  }
}
