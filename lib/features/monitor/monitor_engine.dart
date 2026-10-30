import 'dart:async';
import 'package:dio/dio.dart';

import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

/// UI-independent polling. One request at a time; stale runs cannot publish.
class MonitorEngine {
  MonitorEngine({
    required MonitorConfig config,
    required this.fetch,
    this.manualFetch,
    required this.notify,
    required this.onUpdate,
    this.processAutomatic,
    this.completedAutomaticIds,
    this.terminalAutomaticIds,
    this.automaticNumberCodes,
    this.loadDetectionWindow,
    this.loadAutomaticWindow,
    Set<int> notifiedIds = const {},
    DateTime Function()? now,
  }) : _notifiedIds = {...notifiedIds},
       _now = now ?? DateTime.now {
    _config = config;
  }

  final Future<List<RollcallItem>> Function() fetch;
  final Future<List<RollcallItem>> Function()? manualFetch;
  final Future<DetectionWindow> Function()? loadDetectionWindow;
  final Future<DetectionWindow> Function()? loadAutomaticWindow;
  final Future<bool> Function(List<RollcallItem> items) notify;
  final void Function(MonitorEngineUpdate update) onUpdate;
  final Future<String?> Function(
    List<RollcallItem>,
    MonitorConfig,
    bool Function(),
  )?
  processAutomatic;
  final DateTime Function() _now;
  final Set<int> Function()? completedAutomaticIds;
  final Set<int> Function()? terminalAutomaticIds;
  final Map<int, String> Function()? automaticNumberCodes;
  final Set<int> _notifiedIds;
  late MonitorConfig _config;
  Timer? _timer;
  Timer? _automaticTimer;
  List<RollcallItem>? _latestItems;
  DateTime? _lastAutomaticAt;
  bool _running = false;
  bool _discovering = false;
  bool _busy = false;
  int _generation = 0;
  int _failures = 0;
  DateTime? _nextAt;

  Set<int> get notifiedIds => Set.unmodifiable(_notifiedIds);
  Set<int> get terminalIds => Set.unmodifiable(
    terminalAutomaticIds?.call() ??
        completedAutomaticIds?.call() ??
        const <int>{},
  );

  void start({List<RollcallItem>? handedOffItems}) {
    if (_running) return;
    _running = true;
    _discovering = handedOffItems == null;
    _generation++;
    _latestItems = handedOffItems;
    _lastAutomaticAt = null;
    if (_discovering) {
      _schedule(Duration.zero);
    } else {
      _scheduleAutomatic();
    }
  }

  void stop() {
    _running = false;
    _discovering = false;
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
      (_latestItems?.any(
            (i) => (i.isNumber || i.isRadar) && !i.isAnswered && !i.isExpired,
          ) ??
          false);

  bool get _hasAutomaticWork {
    final terminal =
        terminalAutomaticIds?.call() ??
        completedAutomaticIds?.call() ??
        const <int>{};
    return _config.autoAnswer &&
        processAutomatic != null &&
        (_latestItems?.any(
              (i) =>
                  (i.isNumber || i.isRadar) &&
                  !i.isAnswered &&
                  !i.isExpired &&
                  !terminal.contains(i.rollcallId),
            ) ??
            false);
  }

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
    if (_running && !_discovering && !_hasAutomaticWork) {
      if (_config.courseWatch) {
        _discovering = true;
        _latestItems = null;
        _lastAutomaticAt = null;
        onUpdate(
          MonitorEngineUpdate(
            failures: _failures,
            running: true,
            discovering: true,
          ),
        );
        _schedule(_nextDelay());
        return;
      }
      stop();
      onUpdate(
        MonitorEngineUpdate(
          failures: _failures,
          running: false,
          discovering: false,
        ),
      );
      return;
    }
    if (!_discovering && _running && _hasAutomaticWork) {
      _automaticTimer = Timer(
        _automaticDelay,
        () => unawaited(_pollAutomatic()),
      );
      return;
    }
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
    final completed = completedAutomaticIds?.call() ?? const <int>{};
    final codes = automaticNumberCodes?.call() ?? const <int, String>{};
    _latestItems = [
      for (final item in _latestItems!)
        item.copyWith(
          status: completed.contains(item.rollcallId)
              ? 'on_call_fine'
              : item.status,
          numberCode: item.isNumber
              ? codes[item.rollcallId] ?? item.numberCode
              : item.numberCode,
        ),
    ];
    _lastAutomaticAt = _now();
    return message;
  }

  Future<void> _pollAutomatic() async {
    // Discovery owns the same busy gate. Its finally block reschedules us.
    if (!_running || _busy || !_hasAutomaticWork) return;
    _busy = true;
    final generation = _generation;
    bool current() => _running && generation == _generation;
    try {
      final automaticWindow = loadAutomaticWindow ?? loadDetectionWindow;
      if (automaticWindow != null) {
        final window = await automaticWindow();
        if (!current()) return;
        if (!window.allows(_now())) {
          if (!_discovering) {
            if (_config.courseWatch) {
              _latestItems = null;
              _discovering = true;
              onUpdate(
                MonitorEngineUpdate(
                  failures: _failures,
                  running: true,
                  discovering: true,
                ),
              );
              _schedule(Duration.zero);
              return;
            }
            stop();
            onUpdate(
              MonitorEngineUpdate(
                failures: _failures,
                running: false,
                discovering: false,
                message: '已超出检测时段，请手动确认签到',
              ),
            );
            return;
          }
          _latestItems = null;
          _schedule(Duration.zero);
          return;
        }
      }
      final message = await _processAutomatic(current);
      if (current()) {
        onUpdate(
          MonitorEngineUpdate(
            failures: _failures,
            ok: true,
            message: message,
            items: _latestItems,
          ),
        );
      }
    } catch (error) {
      if (!current()) return;
      if (error is DetectionWindowClosed) {
        _latestItems = null;
        _schedule(Duration.zero);
        return;
      }
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
      if (_running && _discovering && _timer?.isActive != true) {
        _schedule(Duration.zero);
      }
    }
  }

  Duration _nextDelay() => Duration(
    seconds: _config.nextDelay().inSeconds * (1 << _failures.clamp(0, 4)),
  );

  void _schedule(Duration delay) {
    if (!_running || !_discovering) return;
    _timer?.cancel();
    _nextAt = _now().add(delay);
    onUpdate(MonitorEngineUpdate(nextPollAt: _nextAt, failures: _failures));
    _timer = Timer(delay, () => unawaited(pollNow()));
  }

  Future<void> pollNow({bool manual = false}) async {
    if (!_running || !_discovering || _busy) return;
    _timer?.cancel();
    _busy = true;
    final generation = _generation;
    bool current() => _running && generation == _generation;
    Duration? pausedDelay;
    try {
      if (!manual && loadDetectionWindow != null) {
        final window = await loadDetectionWindow!();
        if (!current()) return;
        if (!window.allows(_now())) {
          pausedDelay = window.nextStart(_now()).difference(_now());
          _latestItems = null;
          _automaticTimer?.cancel();
          onUpdate(
            MonitorEngineUpdate(
              failures: _failures,
              ok: true,
              message: '时段外暂停检测（${window.label}）',
              waitingForWindow: true,
            ),
          );
          return;
        }
      }
      onUpdate(
        MonitorEngineUpdate(failures: _failures, waitingForWindow: false),
      );
      final items = await (manual ? (manualFetch ?? fetch) : fetch)();
      if (!current()) return;
      _latestItems = items;
      if (items.any(
        (i) =>
            !i.isExpired &&
            !i.isAnswered &&
            (!_config.courseWatch || !terminalIds.contains(i.rollcallId)),
      )) {
        _discovering = false;
        _nextAt = null;
        onUpdate(
          MonitorEngineUpdate(
            failures: _failures,
            running: true,
            discovering: false,
            items: items,
            message: _config.courseWatch
                ? '已发现待签到活动，处理后继续值守'
                : '已发现待签到活动，停止继续检测',
          ),
        );
      }
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
          items: _latestItems,
          lastPollAt: _now(),
          failures: 0,
          count: items.length,
          ok: true,
          message:
              automaticMessage ??
              (alertFailed
                  ? '已发现 ${items.length} 条签到；通知失败，请在签到页处理'
                  : items.isEmpty
                  ? '检测成功，暂无进行中签到'
                  : _discovering
                  ? '当前活动均已完成，继续寻找待签到活动'
                  : _config.courseWatch
                  ? '已发现待签到活动，处理后继续值守'
                  : '已发现待签到活动，停止继续检测'),
        ),
      );
    } catch (error) {
      if (!current()) return;
      if (error is DetectionWindowClosed) {
        pausedDelay = error.window.nextStart(_now()).difference(_now());
        _latestItems = null;
        onUpdate(
          MonitorEngineUpdate(
            failures: _failures,
            ok: true,
            message: error.toString(),
            waitingForWindow: true,
          ),
        );
        return;
      }
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
      if (_running && _discovering) _schedule(pausedDelay ?? _nextDelay());
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
    this.running,
    this.discovering,
    this.waitingForWindow,
  });

  final DateTime? lastPollAt;
  final DateTime? nextPollAt;
  final int failures;
  final int? count;
  final bool? ok;
  final String? message;
  final List<RollcallItem>? items;
  final bool sessionExpired;
  final bool? running;
  final bool? discovering;
  final bool? waitingForWindow;
}
