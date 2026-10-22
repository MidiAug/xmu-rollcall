import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';

/// Only task metadata belongs in preferences. Cookies stay in secure storage.
class AndroidMonitorRun {
  const AndroidMonitorRun({
    required this.id,
    required this.userId,
    required this.config,
    int? ownerUserId,
    this.assistUserId,
    this.diagnosticOnly = false,
  }) : ownerUserId = ownerUserId ?? userId;

  final String id;
  final int userId;
  final int ownerUserId;
  final int? assistUserId;
  final MonitorConfig config;
  final bool diagnosticOnly;
  String get credentialKey => 'monitor_credential_$id';

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'ownerUserId': ownerUserId,
    'assistUserId': assistUserId,
    'interval': config.effectiveIntervalSeconds,
    'jitter': config.jitterRatio,
    'preset': config.preset.index,
    'autoAnswer': config.autoAnswer,
    'answerWaitMode': config.answerWaitMode.index,
    'answerWaitCount': config.answerWaitCount,
    'answerWaitPercent': config.answerWaitPercent,
    'attendanceInterval': config.effectiveAttendanceIntervalSeconds,
    'diagnosticOnly': diagnosticOnly,
  };

  factory AndroidMonitorRun.fromJson(Map<String, dynamic> json) {
    final interval = (json['interval'] as num).toInt().clamp(15, 120);
    final jitter = (json['jitter'] as num).toDouble().clamp(0.0, 0.5);
    final preset = (json['preset'] as num).toInt().clamp(0, 2);
    return AndroidMonitorRun(
      id: json['id'] as String,
      userId: (json['userId'] as num).toInt(),
      ownerUserId: (json['ownerUserId'] as num?)?.toInt(),
      assistUserId: (json['assistUserId'] as num?)?.toInt(),
      config: MonitorConfig(
        enabled: true,
        intervalSeconds: interval,
        jitterRatio: jitter,
        preset: MonitorPreset.values[preset],
        autoAnswer: json['autoAnswer'] == true,
        attendanceIntervalSeconds:
            ((json['attendanceInterval'] as num?)?.toInt() ?? 20).clamp(
              15,
              120,
            ),
        answerWaitMode:
            AnswerWaitMode.values[((json['answerWaitMode'] as num?)?.toInt() ??
                    2)
                .clamp(0, 2)],
        answerWaitCount: ((json['answerWaitCount'] as num?)?.toInt() ?? 10)
            .clamp(1, 200),
        answerWaitPercent: ((json['answerWaitPercent'] as num?)?.toInt() ?? 10)
            .clamp(1, 100),
      ),
      diagnosticOnly: json['diagnosticOnly'] == true,
    );
  }
}

abstract final class AndroidMonitorStore {
  static const _runKey = 'monitor_run_v2';
  static const _snapshotKey = 'monitor_snapshot_v2';
  static const diagnosticKey = 'monitor_diagnostic_v2';

  static Future<AndroidMonitorRun?> readRun() async {
    final json = await _read(_runKey);
    if (json == null) return null;
    try {
      return AndroidMonitorRun.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeRun(AndroidMonitorRun run) =>
      _write(_runKey, run.toJson());
  static Future<void> clearRun() async {
    await FlutterForegroundTask.removeData(key: _runKey);
    await FlutterForegroundTask.removeData(key: diagnosticKey);
  }

  static Future<Map<String, dynamic>?> readSnapshot() => _read(_snapshotKey);
  static Future<void> writeSnapshot(Map<String, dynamic> snapshot) =>
      _write(_snapshotKey, snapshot);
  static Future<Map<String, dynamic>?> readDiagnostic() => _read(diagnosticKey);
  static Future<void> writeDiagnostic(Map<String, dynamic> diagnostic) =>
      _write(diagnosticKey, diagnostic);

  static Future<Map<String, dynamic>?> _read(String key) async {
    final raw = await FlutterForegroundTask.getData<String>(key: key);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(String key, Map<String, dynamic> data) async {
    if (!await FlutterForegroundTask.saveData(
      key: key,
      value: jsonEncode(data),
    )) {
      throw StateError('Cannot persist monitor state');
    }
  }
}
