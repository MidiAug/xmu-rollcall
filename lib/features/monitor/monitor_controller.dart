import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

class MonitorState {
  const MonitorState({
    required this.config,
    this.running = false,
    this.lastPollAt,
    this.nextPollAt,
    this.logs = const [],
    this.consecutiveFailures = 0,
  });

  final MonitorConfig config;
  final bool running;
  final DateTime? lastPollAt;
  final DateTime? nextPollAt;
  final List<PollLogEntry> logs;
  final int consecutiveFailures;

  MonitorState copyWith({
    MonitorConfig? config,
    bool? running,
    DateTime? lastPollAt,
    DateTime? nextPollAt,
    List<PollLogEntry>? logs,
    int? consecutiveFailures,
    bool clearNext = false,
  }) {
    return MonitorState(
      config: config ?? this.config,
      running: running ?? this.running,
      lastPollAt: lastPollAt ?? this.lastPollAt,
      nextPollAt: clearNext ? null : (nextPollAt ?? this.nextPollAt),
      logs: logs ?? this.logs,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    );
  }
}

final monitorControllerProvider =
    StateNotifierProvider<MonitorController, MonitorState>((ref) {
  return MonitorController(ref);
});

class MonitorController extends StateNotifier<MonitorState> {
  MonitorController(this._ref)
      : super(const MonitorState(config: MonitorConfig())) {
    _load();
  }

  final Ref _ref;
  Timer? _timer;
  Timer? _persistDebounce;
  Timer? _debugDiscoveryTimer;

  static const _kEnabled = 'monitor_enabled';
  static const _kPreset = 'monitor_preset';
  static const _kInterval = 'monitor_interval';
  static const _kJitter = 'monitor_jitter';
  static const _persistDelay = Duration(milliseconds: 400);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final presetIndex = prefs.getInt(_kPreset) ?? 0;
    final preset = MonitorPreset.values[
        presetIndex.clamp(0, MonitorPreset.values.length - 1)];
    final interval = prefs.getInt(_kInterval) ?? preset.defaultSeconds;
    final jitter = prefs.getDouble(_kJitter) ?? 0.2;
    state = state.copyWith(
      config: MonitorConfig(
        enabled: false, // never auto-start on launch
        preset: preset,
        intervalSeconds: interval < MonitorConfig.minIntervalSeconds
            ? MonitorConfig.minIntervalSeconds
            : interval,
        jitterRatio: jitter,
        autoAnswer: false,
      ),
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final c = state.config;
    await prefs.setInt(_kPreset, c.preset.index);
    await prefs.setInt(_kInterval, c.effectiveIntervalSeconds);
    await prefs.setDouble(_kJitter, c.jitterRatio);
    await prefs.setBool(_kEnabled, c.enabled);
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(_persistDelay, () {
      _persist();
    });
  }

  /// Flush pending prefs write (call from slider [onChangeEnd]).
  void commitPersist() {
    _persistDebounce?.cancel();
    _persistDebounce = null;
    _persist();
  }

  void setPreset(MonitorPreset preset) {
    final interval =
        preset == MonitorPreset.custom ? state.config.intervalSeconds : preset.defaultSeconds;
    state = state.copyWith(
      config: state.config.copyWith(preset: preset, intervalSeconds: interval),
    );
    commitPersist();
    if (state.running) {
      stop();
      start();
    }
  }

  void setIntervalSeconds(int seconds) {
    final clamped =
        seconds < MonitorConfig.minIntervalSeconds ? MonitorConfig.minIntervalSeconds : seconds;
    final c = state.config;
    if (c.intervalSeconds == clamped && c.preset == MonitorPreset.custom) {
      return;
    }
    state = state.copyWith(
      config: c.copyWith(
        preset: MonitorPreset.custom,
        intervalSeconds: clamped,
      ),
    );
    _schedulePersist();
  }

  void setJitterRatio(double ratio) {
    final next = ratio.clamp(0.0, 0.5);
    if (state.config.jitterRatio == next) return;
    state = state.copyWith(
      config: state.config.copyWith(jitterRatio: next),
    );
    _schedulePersist();
  }

  void start() {
    if (state.running) return;
    if (!_ref.read(authControllerProvider).isSignedIn) return;
    state = state.copyWith(
      running: true,
      config: state.config.copyWith(enabled: true),
      consecutiveFailures: 0,
    );
    _persist();
    _schedule(immediate: true);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(
      running: false,
      config: state.config.copyWith(enabled: false),
      clearNext: true,
    );
    _persist();
  }

  /// Fire the next poll immediately (running only).
  void pollNow() {
    if (!state.running) return;
    _schedule(immediate: true);
  }

  @override
  void dispose() {
    _persistDebounce?.cancel();
    _debugDiscoveryTimer?.cancel();
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  /// Debug: mark monitor running without hitting the network (for tray busy / L2).
  void debugArmRunning() {
    assert(kDebugMode, 'debugArmRunning is debug-only');
    if (!kDebugMode) return;
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(
      running: true,
      config: state.config.copyWith(enabled: true),
      consecutiveFailures: 0,
      clearNext: true,
    );
  }

  /// Debug L2: after [delay], seed a fake active rollcall and take the real
  /// discovery-stop + notify path (same as a successful poll with non-empty list).
  void debugScheduleDiscovery({
    Duration delay = const Duration(seconds: 10),
    int count = 1,
  }) {
    assert(kDebugMode, 'debugScheduleDiscovery is debug-only');
    if (!kDebugMode) return;
    debugArmRunning();
    _debugDiscoveryTimer?.cancel();
    _debugDiscoveryTimer = Timer(delay, () {
      unawaited(_debugFireDiscovery(count: count));
    });
    AppLog.event(
      'poll.debug_schedule',
      fields: {'delayMs': delay.inMilliseconds, 'count': count},
    );
  }

  void debugCancelScheduledDiscovery() {
    _debugDiscoveryTimer?.cancel();
    _debugDiscoveryTimer = null;
  }

  Future<void> _debugFireDiscovery({required int count}) async {
    final items = <RollcallItem>[
      for (var i = 0; i < count; i++)
        RollcallItem(
          rollcallId: -9100 - i,
          courseTitle: '调试签到（预览 ${i + 1}）',
          createdByName: '开发预览',
          type: RollcallType.number,
          status: 'on_call',
          rollcallStatus: 'on_call',
          isExpired: false,
          scored: false,
          raw: const {'course_id': 'preview-debug-course'},
          numberCode: '1234',
        ),
    ];
    _ref.read(activeRollcallsProvider(null).notifier).debugSeed(items);
    await _finishDiscovery(
      count: items.length,
      intervalMs: 0,
      logMessage: '发现进行中 ${items.length} 条，已停止检测（调试）',
    );
  }

  Future<void> _finishDiscovery({
    required int count,
    required int intervalMs,
    required String logMessage,
  }) async {
    final entry = PollLogEntry(
      at: DateTime.now(),
      ok: true,
      message: logMessage,
    );
    AppLog.event(
      'poll.tick',
      fields: {
        'count': count,
        'intervalMs': intervalMs,
        'ok': true,
      },
    );
    _timer?.cancel();
    _timer = null;
    _debugDiscoveryTimer?.cancel();
    _debugDiscoveryTimer = null;
    state = state.copyWith(
      running: false,
      config: state.config.copyWith(enabled: false),
      lastPollAt: entry.at,
      consecutiveFailures: 0,
      logs: [entry, ...state.logs].take(40).toList(),
      clearNext: true,
    );
    await _persist();
    final notify = PlatformHooks.onRollcallsDiscovered;
    if (notify != null) {
      try {
        await notify(count);
      } catch (_) {}
    }
  }

  void _schedule({bool immediate = false}) {
    _timer?.cancel();
    if (!state.running) return;

    final failures = state.consecutiveFailures;
    final backoffFactor = failures == 0 ? 1 : (1 << (failures.clamp(0, 4)));
    var delay = immediate ? Duration.zero : state.config.nextDelay();
    if (!immediate && failures > 0) {
      delay = Duration(seconds: delay.inSeconds * backoffFactor);
    }
    final nextAt = DateTime.now().add(delay);
    state = state.copyWith(nextPollAt: nextAt);

    _timer = Timer(delay, _tick);
  }

  Future<void> _tick() async {
    if (!state.running) return;
    final intervalMs = state.config.nextDelay().inMilliseconds;
    try {
      await _ref.read(activeRollcallsProvider(null).notifier).refresh();
      final list =
          _ref.read(activeRollcallsProvider(null)).valueOrNull ?? const [];
      if (list.isNotEmpty) {
        await _finishDiscovery(
          count: list.length,
          intervalMs: intervalMs,
          logMessage: '发现进行中 ${list.length} 条，已停止检测',
        );
        return;
      }
      final entry = PollLogEntry(
        at: DateTime.now(),
        ok: true,
        message: '检测成功，暂无进行中签到',
        nextIn: state.config.nextDelay(),
      );
      AppLog.event(
        'poll.tick',
        fields: {
          'count': 0,
          'intervalMs': intervalMs,
          'ok': true,
        },
      );
      state = state.copyWith(
        lastPollAt: entry.at,
        consecutiveFailures: 0,
        logs: [entry, ...state.logs].take(40).toList(),
      );
    } catch (e) {
      AppLog.event(
        'poll.tick',
        level: 'W',
        fields: {
          'count': 0,
          'intervalMs': intervalMs,
          'ok': false,
          'errorType': e.runtimeType.toString(),
        },
      );
      final entry = PollLogEntry(
        at: DateTime.now(),
        ok: false,
        message: '失败：$e',
      );
      state = state.copyWith(
        lastPollAt: entry.at,
        consecutiveFailures: state.consecutiveFailures + 1,
        logs: [entry, ...state.logs].take(40).toList(),
      );
    }
    _schedule();
  }
}
