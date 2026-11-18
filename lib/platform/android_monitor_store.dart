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
    final interval = MonitorConfig.normalizeIntervalSeconds(
      (json['interval'] as num).toInt(),
    );
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
  static const _runsKey = 'monitor_runs_v3';
  static const _snapshotKey = 'monitor_snapshot_v2';
  static const diagnosticKey = 'monitor_diagnostic_v2';

  static Future<AndroidMonitorRun?> _readLegacyRun() async {
    final json = await _read(_runKey);
    if (json == null) return null;
    try {
      final run = AndroidMonitorRun.fromJson(json);
      return await _isRevoked(run.id) ? null : run;
    } catch (_) {
      return null;
    }
  }

  static Future<List<AndroidMonitorRun>> readRuns() async {
    final index = await _read(_runsKey);
    if (index == null) {
      final legacy = await _readLegacyRun();
      return legacy == null ? [] : [legacy];
    }
    final runs = <AndroidMonitorRun>[];
    for (final id in (index['ids'] as List? ?? []).whereType<String>()) {
      if (await _isRevoked(id)) continue;
      final raw = await _read('monitor_run_v3_$id');
      if (raw == null) continue;
      try {
        runs.add(AndroidMonitorRun.fromJson(raw));
      } catch (_) {
        // Ignore invalid metadata without affecting other accounts.
      }
    }
    return runs;
  }

  static Future<AndroidMonitorRun?> readRun({String? runId}) async {
    final runs = await readRuns();
    return runId == null
        ? runs.firstOrNull
        : runs.where((r) => r.id == runId).firstOrNull;
  }

  static Future<void> writeRun(AndroidMonitorRun run) async {
    if (await _isRevoked(run.id)) throw StateError('Monitor grant revoked');
    final runs = await readRuns();
    if (await _read(_runsKey) == null) {
      for (final existing in runs) {
        if (existing.id != run.id) {
          await _write('monitor_run_v3_${existing.id}', existing.toJson());
        }
      }
    }
    await _write('monitor_run_v3_${run.id}', run.toJson());
    await _write(_runsKey, {
      'ids': {...runs.map((r) => r.id), run.id}.toList(),
    });
    await FlutterForegroundTask.removeData(key: _runKey);
  }

  /// Revoke one durable grant. Workers never rewrite the shared index.
  static Future<void> clearRun({String? runId}) async {
    final runs = await readRuns();
    for (final run in runs) {
      if (runId == null || run.id == runId) {
        await FlutterForegroundTask.saveData(
          key: 'monitor_revoked_${run.id}',
          value: true,
        );
        await FlutterForegroundTask.removeData(key: 'monitor_run_v3_${run.id}');
      }
    }
    final legacy = await _readLegacyRun();
    if (runId == null || legacy?.id == runId) {
      await FlutterForegroundTask.removeData(key: _runKey);
    }
    if (runId == null) {
      await FlutterForegroundTask.removeData(key: diagnosticKey);
    }
  }

  static Future<bool> _isRevoked(String id) async =>
      await FlutterForegroundTask.getData<bool>(key: 'monitor_revoked_$id') ==
      true;

  static Future<Map<String, dynamic>?> readSnapshot({String? runId}) async {
    if (runId == null) return _read(_snapshotKey);
    final scoped = await _read('${_snapshotKey}_$runId');
    if (scoped != null) return scoped;
    final legacy = await _read(_snapshotKey);
    return legacy?['runId'] == runId ? legacy : null;
  }

  static Future<Map<String, dynamic>?> readAccountSnapshot(
    int ownerUserId,
    int? assistUserId,
  ) => _read(
    '${_snapshotKey}_account_${ownerUserId}_${assistUserId ?? 'owner'}',
  );

  static Future<void> writeSnapshot(Map<String, dynamic> snapshot) async {
    await _write('${_snapshotKey}_${snapshot['runId']}', snapshot);
    await _write(
      '${_snapshotKey}_account_${snapshot['ownerUserId'] ?? snapshot['userId']}_${snapshot['assistUserId'] ?? 'owner'}',
      snapshot,
    );
  }

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
