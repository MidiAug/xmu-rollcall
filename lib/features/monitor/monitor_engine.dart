import 'dart:async';
import 'package:dio/dio.dart';

import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

/// UI-independent polling. One request at a time; stale runs cannot publish.
class MonitorEngine {
  MonitorEngine({
    required MonitorConfig config,
    required this.fetch,
    required this.notify,
    required this.onUpdate,
    this.processAutomatic,
    Set<int> notifiedIds = const {},
    DateTime Function()? now,
  }) : _notifiedIds = {...notifiedIds},
       _now = now ?? DateTime.now {
    _config = config;
  }

  final Future<List<RollcallItem>> Function() fetch;
  final Future<bool> Function(List<RollcallItem> items) notify;
  final void Function(MonitorEngineUpdate update) onUpdate;
  final Future<String?> Function(
    List<RollcallItem>,
    MonitorConfig,
    bool Function(),
  )?
  processAutomatic;
  final DateTime Function() _now;
  final Set<int> _notifiedIds;
  late MonitorConfig _config;
  Timer? _timer;
  Timer? _automaticTimer;
  List<RollcallItem>? _latestItems;
  DateTime? _lastAutomaticAt;
  bool _running = false;
  bool _busy = false;
  int _generation = 0;
  int _failures = 0;
  DateTime? _nextAt;

  Set<int> get notifiedIds => Set.unmodifiable(_notifiedIds);

  void start() {
    if (_running) return;
    _running = true;
    _generation++;
    _latestItems = null;
    _lastAutomaticAt = null;
    _schedule(Duration.zero);
  }

  void stop() {
    _running = false;
    _generation++;
    _timer?.cancel();
    _automaticTimer?.cancel();
    _nextAt = null;
  }

  void updateConfig(MonitorConfig config) {
    _config = config;
    _automaticTimer?.cancel();
    _lastAutomaticAt = null;
    if (!_busy) _scheduleAutomatic();
    if (_running && !_busy) _schedule(_nextDelay());
  }

  bool get _waitsForAttendance =>
      _config.autoAnswer &&
      _config.answerWaitMode != AnswerWaitMode.none &&
      processAutomatic != null &&
      (_latestItems?.any((i) => i.isNumber && !i.isAnswered && !i.isExpired) ??
          false);

  Duration get _automaticDelay {
    final last = _lastAutomaticAt;
    if (last == null) return Duration.zero;
    final remaining = last
        .add(Duration(seconds: _config.effectiveAttendanceIntervalSeconds))
        .difference(_now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _scheduleAutomatic() {
    _automaticTimer?.cancel();
    if (!_running || !_waitsForAttendance || _latestItems == null) return;
    _automaticTimer = Timer(_automaticDelay, () => unawaited(_pollAutomatic()));
  }

  Future<String?> _processAutomatic(bool Function() current) async {
    final config = _config;
    if (!config.autoAnswer || processAutomatic == null) return null;
    if (_waitsForAttendance && _automaticDelay > Duration.zero) return null;
    final message = await processAutomatic!(
      _latestItems!,
      config,
      () => current() && identical(config, _config) && _config.autoAnswer,
    );
    if (!current() || !identical(config, _config)) return null;
    _lastAutomaticAt = _now();
    return message;
  }

  Future<void> _pollAutomatic() async {
    // Discovery owns the same busy gate. Its finally block reschedules us.
    if (!_running || _busy || !_waitsForAttendance) return;
    _busy = true;
    final generation = _generation;
    bool current() => _running && generation == _generation;
    try {
      final message = await _processAutomatic(current);
      if (current() && message != null) {
        onUpdate(
          MonitorEngineUpdate(failures: _failures, ok: true, message: message),
        );
      }
    } catch (error) {
      if (!current()) return;
      _lastAutomaticAt = _now();
      if (error is DioException &&
          (error.response?.statusCode == 401 ||
              error.response?.statusCode == 403)) {
        stop();
        onUpdate(
          MonitorEngineUpdate(
            failures: _failures,
            ok: false,
            sessionExpired: true,
            message: '登录已失效，请重新登录后开始检测',
          ),
        );
      } else {
        onUpdate(
          MonitorEngineUpdate(
            failures: _failures,
            ok: false,
            message: '人数检查失败，稍后重试',
          ),
        );
      }
    } finally {
      _busy = false;
      _scheduleAutomatic();
      // A discovery timer may have fired while this request held the gate.
      if (_running && _timer?.isActive != true) _schedule(Duration.zero);
    }
  }

  Duration _nextDelay() => Duration(
    seconds: _config.nextDelay().inSeconds * (1 << _failures.clamp(0, 4)),
  );

  void _schedule(Duration delay) {
    if (!_running) return;
    _timer?.cancel();
    _nextAt = _now().add(delay);
    onUpdate(MonitorEngineUpdate(nextPollAt: _nextAt, failures: _failures));
    _timer = Timer(delay, () => unawaited(pollNow()));
  }

  Future<void> pollNow() async {
    if (!_running || _busy) return;
    _timer?.cancel();
    _busy = true;
    final generation = _generation;
    bool current() => _running && generation == _generation;
    try {
      final items = await fetch();
      if (!current()) return;
      _latestItems = items;
      final fresh = items
          .where(
            (i) =>
                !i.isExpired &&
                !i.isAnswered &&
                !_notifiedIds.contains(i.rollcallId),
          )
          .toList();
      var alertFailed = false;
      if (fresh.isNotEmpty) {
        try {
          final delivered = await notify(fresh);
          if (!current()) return;
          if (delivered) {
            _notifiedIds.addAll(fresh.map((i) => i.rollcallId));
          } else {
            alertFailed = true;
          }
        } catch (_) {
          if (!current()) return;
          alertFailed = true;
        }
      }
      final automaticMessage = await _processAutomatic(current);
      if (!current()) return;
      _failures = 0;
      onUpdate(
        MonitorEngineUpdate(
          items: items,
          lastPollAt: _now(),
          failures: 0,
          count: items.length,
          ok: true,
          message:
              automaticMessage ??
              (alertFailed
                  ? '检测成功，发现 ${items.length} 条签到；通知失败，下次重试'
                  : items.isEmpty
                  ? '检测成功，暂无进行中签到'
                  : '发现进行中签到 ${items.length} 条，继续检测'),
        ),
      );
    } catch (error) {
      if (!current()) return;
      if (error is DioException &&
          (error.response?.statusCode == 401 ||
              error.response?.statusCode == 403)) {
        stop();
        onUpdate(
          MonitorEngineUpdate(
            failures: _failures,
            ok: false,
            sessionExpired: true,
            message: '登录已失效，请重新登录后开始检测',
          ),
        );
        return;
      }
      _failures++;
      onUpdate(
        MonitorEngineUpdate(
          lastPollAt: _now(),
          failures: _failures,
          ok: false,
          message: '检测失败：${error.runtimeType}，稍后重试',
        ),
      );
    } finally {
      _busy = false;
      if (_running) _schedule(_nextDelay());
      _scheduleAutomatic();
    }
  }
}

class MonitorEngineUpdate {
  const MonitorEngineUpdate({
    this.lastPollAt,
    this.nextPollAt,
    required this.failures,
    this.count,
    this.ok,
    this.message,
    this.items,
    this.sessionExpired = false,
  });

  final DateTime? lastPollAt;
  final DateTime? nextPollAt;
  final int failures;
  final int? count;
  final bool? ok;
  final String? message;
  final List<RollcallItem>? items;
  final bool sessionExpired;
}
