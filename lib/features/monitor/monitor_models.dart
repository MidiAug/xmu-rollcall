import 'dart:math';

/// Poll interval presets and jitter helpers (KB-01).
enum MonitorPreset {
  classroom,
  eco,
  custom,
}

extension MonitorPresetX on MonitorPreset {
  String get label => switch (this) {
        MonitorPreset.classroom => '课堂',
        MonitorPreset.eco => '省电',
        MonitorPreset.custom => '自定义',
      };

  /// Default seconds for built-in presets.
  int get defaultSeconds => switch (this) {
        MonitorPreset.classroom => 20,
        MonitorPreset.eco => 60,
        MonitorPreset.custom => 30,
      };
}

class MonitorConfig {
  const MonitorConfig({
    this.enabled = false,
    this.preset = MonitorPreset.classroom,
    this.intervalSeconds = 20,
    this.jitterRatio = 0.2,
    this.autoAnswer = false,
  });

  final bool enabled;
  final MonitorPreset preset;
  final int intervalSeconds;
  final double jitterRatio;

  /// Always default false (KB-01).
  final bool autoAnswer;

  static const minIntervalSeconds = 15;

  int get effectiveIntervalSeconds =>
      intervalSeconds < minIntervalSeconds ? minIntervalSeconds : intervalSeconds;

  MonitorConfig copyWith({
    bool? enabled,
    MonitorPreset? preset,
    int? intervalSeconds,
    double? jitterRatio,
    bool? autoAnswer,
  }) {
    return MonitorConfig(
      enabled: enabled ?? this.enabled,
      preset: preset ?? this.preset,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      jitterRatio: jitterRatio ?? this.jitterRatio,
      autoAnswer: autoAnswer ?? this.autoAnswer,
    );
  }

  /// Next delay = base ± jitter, never below [minIntervalSeconds].
  Duration nextDelay([Random? random]) {
    final rand = random ?? Random();
    final base = effectiveIntervalSeconds;
    final jitter = (base * jitterRatio).round();
    final delta = jitter == 0 ? 0 : rand.nextInt(jitter * 2 + 1) - jitter;
    final seconds = max(minIntervalSeconds, base + delta);
    return Duration(seconds: seconds);
  }
}

class PollLogEntry {
  const PollLogEntry({
    required this.at,
    required this.ok,
    required this.message,
    this.nextIn,
  });

  final DateTime at;
  final bool ok;
  final String message;
  final Duration? nextIn;
}
