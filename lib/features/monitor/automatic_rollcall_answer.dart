import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/log_redactor.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';

import 'package:dio/dio.dart';

class AutomaticRollcallAnswer {
  AutomaticRollcallAnswer({
    required this.repository,
    required this.requireCurrent,
    DateTime Function()? now,
    this.onAnswered,
    this.radarLocation,
    this.runId,
  }) : _now = now ?? DateTime.now;
  final RollcallRepository repository;
  final Future<void> Function() requireCurrent;
  final Future<void> Function(RollcallItem, AnswerResult)? onAnswered;
  final Future<CourseRadarPref?> Function(RollcallItem)? radarLocation;
  final DateTime Function() _now;
  final String? runId;
  final _numberCodes = <int, String>{};
  Map<int, String> get numberCodes => Map.unmodifiable(_numberCodes);
  final _completed = <int>{};
  final _roundStarted = <int, DateTime>{};
  final _retryAt = <int, DateTime>{};
  final _radarAttempted = <int>{};

  Set<int> get completedIds => Set.unmodifiable(_completed);

  Future<CourseRadarPref?> _location(RollcallItem item) async {
    final id = item.courseId;
    if (id == null || id.isEmpty || radarLocation == null) return null;
    final pref = await radarLocation!(item);
    if (pref == null || pref.courseId != id) return null;
    validateRadarLocation(
      latitude: pref.latitude,
      longitude: pref.longitude,
      accuracy: pref.accuracy,
    );
    return pref;
  }

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
      if ((!item.isNumber && !item.isRadar) ||
          item.isAnswered ||
          item.isExpired ||
          _completed.contains(id)) {
        continue;
      }
      if (item.isRadar && _radarAttempted.contains(id)) continue;
      if (_retryAt[id]?.isAfter(_now()) == true) continue;
      final opId = AppLog.newOpId();
      final elapsed = Stopwatch()..start();
      var stage = 'identity';
      void trace(
        String event, [
        Map<String, dynamic> fields = const {},
        String level = 'I',
      ]) {
        AppLog.event(
          event,
          level: level,
          opId: opId,
          fields: {
            'runId': ?runId,
            'rollcallId': id,
            'courseId': item.courseId,
            'type': item.type.name,
            'stage': stage,
            ...fields,
          },
        );
      }

      trace('monitor.auto.start', {
        'waitMode': config.answerWaitMode.name,
        'waitCount': config.answerWaitCount,
        'waitPercent': config.answerWaitPercent,
      });
      try {
        await requireCurrent();
        if (!current()) break;
        if (item.isRadar && await _location(item) == null) {
          trace('monitor.auto.decision', {'reason': 'missing_course_location'});
          message = '雷达签到需先为本课设置位置或完成一次成功签到';
          continue;
        }
        if (!current()) break;
        final start = _roundStarted.putIfAbsent(id, _now);
        if (_now().difference(start) >= const Duration(minutes: 5)) {
          _roundStarted[id] = _now();
          trace('monitor.auto.wait_timeout');
          message = '等待人数超时，下一轮重新检查签到';
          continue;
        }
        if (config.answerWaitMode != AnswerWaitMode.none) {
          stage = 'attendance';
          final count = await repository.fetchAttendanceCount(id, opId: opId);
          if (!current()) break;
          final target = config.answerWaitMode == AnswerWaitMode.count
              ? config.answerWaitCount.clamp(1, 200)
              : (count.total * config.answerWaitPercent.clamp(1, 100) / 100)
                    .ceil();
          trace('monitor.auto.wait', {
            'signed': count.signed,
            'total': count.total,
            'target': target,
          });
          if (count.signed < target) {
            message = target >= count.total
                ? '当前 ${count.signed}/$target 人；课程共 ${count.total} 人，门槛可能无法达到，请调整规则'
                : '等待同学签到：${count.signed}/$target 人';
            continue;
          }
        }
        // Refresh the event and code after waiting, immediately before submission.
        stage = 'revalidate';
        final latest = await repository.fetchActive(opId: opId);
        if (!current()) break;
        final matches = latest.where((i) => i.rollcallId == id);
        if (matches.isEmpty ||
            matches.first.isExpired ||
            matches.first.isAnswered ||
            matches.first.type != item.type ||
            (item.isRadar && matches.first.courseId != item.courseId)) {
          trace('monitor.auto.decision', {
            'reason': 'event_unavailable_or_changed',
          });
          continue;
        }
        stage = 'number_code';
        final code = item.isNumber
            ? await repository.fetchNumberCode(id, opId: opId)
            : null;
        trace('monitor.auto.code_resolved', {
          'available': code?.isNotEmpty == true,
        });
        await requireCurrent();
        if (!current()) break;
        // Read the point last, so a user change during any earlier await wins.
        final location = item.isRadar ? await _location(item) : null;
        if (!current()) break;
        if (_now().difference(start) >= const Duration(minutes: 5)) {
          _roundStarted[id] = _now();
          trace('monitor.auto.wait_timeout');
          message = '等待人数超时，下一轮重新检查签到';
          continue;
        }
        if (item.isNumber && (code == null || code.isEmpty)) {
          trace('monitor.auto.decision', {'reason': 'missing_number_code'});
          message = '自动签到等待有效数字码';
          continue;
        }
        if (item.isRadar && location == null) {
          trace('monitor.auto.decision', {'reason': 'course_location_changed'});
          message = '本课位置已变更，请确认位置后重试';
          continue;
        }
        // Mark an attempt before sending: transport failures must not trigger
        // immediate duplicate submissions. The next cycle rechecks server state.
        _retryAt[id] = _now().add(const Duration(seconds: 60));
        if (code != null && code.isNotEmpty) {
          _numberCodes[id] = code;
          while (_numberCodes.length > 100) {
            _numberCodes.remove(_numberCodes.keys.first);
          }
        }
        stage = 'submit';
        trace('monitor.auto.submit', {
          'codeAvailable': code != null,
          if (location != null)
            'locationSource': location.userConfigured
                ? 'configured'
                : 'previous_success',
        });
        final result = item.isRadar
            ? await repository.answerRadar(
                rollcallId: id,
                latitude: location!.latitude,
                longitude: location.longitude,
                accuracy: location.accuracy,
                opId: opId,
                beforeSend: () async {
                  await requireCurrent();
                  if (!current()) {
                    throw StateError('Automatic radar task changed');
                  }
                  final latestPoint = await _location(item);
                  if (!current() ||
                      latestPoint == null ||
                      latestPoint.latitude != location.latitude ||
                      latestPoint.longitude != location.longitude ||
                      latestPoint.accuracy != location.accuracy ||
                      latestPoint.placeId != location.placeId) {
                    throw StateError(
                      'Automatic radar location changed before send',
                    );
                  }
                  // Only a request that reaches the send boundary consumes the attempt.
                  if (_radarAttempted.contains(id)) {
                    throw StateError('Automatic radar already attempted');
                  }
                  _radarAttempted.add(id);
                },
              )
            : await repository.answerNumber(
                rollcallId: id,
                numberCode: code!,
                opId: opId,
              );
        trace('monitor.auto.result', {'ok': result.ok}, result.ok ? 'I' : 'W');
        if (result.ok) {
          _completed.add(id);
          message = '自动签到成功：${item.courseTitle}';
        } else {
          message = item.isRadar ? '雷达自动签到未成功，请手动确认位置' : '自动签到未成功，稍后重新检查';
        }
        if (current()) {
          stage = 'feedback';
          try {
            await onAnswered?.call(
              code == null ? item : item.copyWith(numberCode: code),
              result,
            );
            trace('monitor.auto.feedback', {'ok': true});
          } catch (error, stack) {
            // Submission has finished: feedback failure must not cause a retry.
            trace('monitor.auto.feedback', {
              'ok': false,
              ...LogRedactor.exceptionFields(error: error, stackTrace: stack),
            }, 'W');
          }
        }
      } catch (error, stack) {
        AppLog.event(
          'monitor.auto.error',
          level: 'W',
          opId: opId,
          fields: {
            'runId': ?runId,
            'rollcallId': id,
            'stage': stage,
            ...LogRedactor.exceptionFields(error: error, stackTrace: stack),
          },
        );
        if (!current()) break;
        if (error is DioException &&
            (error.response?.statusCode == 401 ||
                error.response?.statusCode == 403)) {
          rethrow;
        }
        _retryAt[id] = _now().add(const Duration(seconds: 60));
        message = item.isRadar && _radarAttempted.contains(id)
            ? '雷达提交结果未确认，请打开签到页检查，暂不重复提交'
            : '自动签到暂不可用，稍后重新检查';
      } finally {
        trace('monitor.auto.end', {
          'durationMs': elapsed.elapsedMilliseconds,
          'completed': _completed.contains(id),
          'current': current(),
        });
      }
    }
    return message;
  }
}
