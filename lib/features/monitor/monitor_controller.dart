import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

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

  static const _kEnabled = 'monitor_enabled';
  static const _kPreset = 'monitor_preset';
  static const _kInterval = 'monitor_interval';
  static const _kJitter = 'monitor_jitter';

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

  void setPreset(MonitorPreset preset) {
    final interval =
        preset == MonitorPreset.custom ? state.config.intervalSeconds : preset.defaultSeconds;
    state = state.copyWith(
      config: state.config.copyWith(preset: preset, intervalSeconds: interval),
    );
    _persist();
    if (state.running) {
      stop();
      start();
    }
  }

  void setIntervalSeconds(int seconds) {
    final clamped =
        seconds < MonitorConfig.minIntervalSeconds ? MonitorConfig.minIntervalSeconds : seconds;
    state = state.copyWith(
      config: state.config.copyWith(
        preset: MonitorPreset.custom,
        intervalSeconds: clamped,
      ),
    );
    _persist();
  }

  void setJitterRatio(double ratio) {
    state = state.copyWith(
      config: state.config.copyWith(jitterRatio: ratio.clamp(0, 0.5)),
    );
    _persist();
  }

  void start() {
    if (state.running) return;
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

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
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
    try {
      await _ref.read(activeRollcallsProvider.notifier).refresh();
      final list = _ref.read(activeRollcallsProvider).valueOrNull ?? const [];
      final entry = PollLogEntry(
        at: DateTime.now(),
        ok: true,
        message: '拉取成功，进行中 ${list.length} 条',
        nextIn: state.config.nextDelay(),
      );
      state = state.copyWith(
        lastPollAt: entry.at,
        consecutiveFailures: 0,
        logs: [entry, ...state.logs].take(40).toList(),
      );
    } catch (e) {
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
