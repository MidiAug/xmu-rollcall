import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

import 'package:dio/dio.dart';

class AutomaticNumberAnswer {
  AutomaticNumberAnswer({
    required this.repository,
    required this.requireCurrent,
    DateTime Function()? now,
    this.onAnswered,
  }) : _now = now ?? DateTime.now;
  final RollcallRepository repository;
  final Future<void> Function() requireCurrent;
  final Future<void> Function(RollcallItem, AnswerResult)? onAnswered;
  final DateTime Function() _now;
  final _completed = <int>{};
  final _roundStarted = <int, DateTime>{};
  final _retryAt = <int, DateTime>{};

  Future<String?> process(
    List<RollcallItem> items,
    MonitorConfig config,
    bool Function() current,
  ) async {
    if (!config.autoAnswer || !current()) return null;
    final activeIds = items.map((i) => i.rollcallId).toSet();
    _roundStarted.removeWhere((id, _) => !activeIds.contains(id));
    _retryAt.removeWhere((id, _) => !activeIds.contains(id));
    String? message;
    for (final item in items) {
      if (!current()) break;
      final id = item.rollcallId;
      if (!item.isNumber ||
          item.isAnswered ||
          item.isExpired ||
          _completed.contains(id)) {
        continue;
      }
      if (_retryAt[id]?.isAfter(_now()) == true) continue;
      try {
        await requireCurrent();
        if (!current()) break;
        final start = _roundStarted.putIfAbsent(id, _now);
        if (_now().difference(start) >= const Duration(minutes: 5)) {
          _roundStarted[id] = _now();
          AppLog.event('monitor.auto.wait_timeout', fields: {'rollcallId': id});
          message = '等待人数超时，下一轮重新检查签到';
          continue;
        }
        if (config.answerWaitMode != AnswerWaitMode.none) {
          final count = await repository.fetchAttendanceCount(id);
          if (!current()) break;
          final target = config.answerWaitMode == AnswerWaitMode.count
              ? config.answerWaitCount.clamp(1, 200)
              : (count.total * config.answerWaitPercent.clamp(1, 100) / 100)
                    .ceil();
          AppLog.event(
            'monitor.auto.wait',
            fields: {
              'rollcallId': id,
              'signed': count.signed,
              'total': count.total,
              'target': target,
            },
          );
          if (count.signed < target) {
            message = target >= count.total
                ? '当前 ${count.signed}/$target 人；课程共 ${count.total} 人，门槛可能无法达到，请调整规则'
                : '等待同学签到：${count.signed}/$target 人';
            continue;
          }
        }
        // Refresh the event and code after waiting, immediately before submission.
        final latest = await repository.fetchActive();
        if (!current()) break;
        final matches = latest.where((i) => i.rollcallId == id);
        if (matches.isEmpty ||
            matches.first.isExpired ||
            matches.first.isAnswered ||
            !matches.first.isNumber) {
          continue;
        }
        final code = await repository.fetchNumberCode(id);
        await requireCurrent();
        if (!current()) break;
        if (_now().difference(start) >= const Duration(minutes: 5)) {
          _roundStarted[id] = _now();
          message = '等待人数超时，下一轮重新检查签到';
          continue;
        }
        if (code == null || code.isEmpty) {
          message = '自动签到等待有效数字码';
          continue;
        }
        // Mark an attempt before sending: transport failures must not trigger
        // immediate duplicate submissions. The next cycle rechecks server state.
        _retryAt[id] = _now().add(const Duration(seconds: 60));
        final result = await repository.answerNumber(
          rollcallId: id,
          numberCode: code,
        );
        AppLog.event(
          'monitor.auto.result',
          fields: {'rollcallId': id, 'ok': result.ok},
        );
        if (result.ok) {
          _completed.add(id);
          message = '自动签到成功：${item.courseTitle}';
        } else {
          message = '自动签到未成功，稍后重新检查';
        }
        if (current()) await onAnswered?.call(item, result);
      } catch (error) {
        if (!current()) break;
        if (error is DioException &&
            (error.response?.statusCode == 401 ||
                error.response?.statusCode == 403)) {
          rethrow;
        }
        _retryAt[id] = _now().add(const Duration(seconds: 60));
        AppLog.event(
          'monitor.auto.error',
          level: 'W',
          fields: {'rollcallId': id, 'errorType': error.runtimeType.toString()},
        );
        message = '自动签到暂不可用，稍后重新检查';
      }
    }
    return message;
  }
}
