import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository_providers.dart';

final attendanceCountClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final _automaticCountWaitProvider = Provider.family<bool, int?>((
  ref,
  accountId,
) {
  final selected = ref.watch(selectedRollcallAccountProvider);
  final config = ref.watch(monitorControllerProvider.select((s) => s.config));
  return selected == accountId &&
      config.autoAnswer &&
      config.answerWaitMode != AnswerWaitMode.none;
});

// In-memory per identity, so rebuilding or scrolling a card cannot resume it.
final _pausedCountActivitiesProvider =
    StateProvider.family<
      Map<int, AttendanceCount?>,
      ({int ownerId, int? accountId})
    >((ref, key) {
      ref.watch(authControllerProvider.select((s) => s.profile?.id));
      ref.watch(_automaticCountWaitProvider(key.accountId));
      return <int, AttendanceCount?>{};
    });

/// Poll while visible, including when a desktop window only loses focus.
class AttendanceCountRow extends ConsumerStatefulWidget {
  const AttendanceCountRow({
    super.key,
    required this.rollcallId,
    required this.expired,
    this.assistUserId,
  });

  final int rollcallId;
  final int? assistUserId;
  final bool expired;

  @override
  ConsumerState<AttendanceCountRow> createState() => _AttendanceCountRowState();
}

class _AttendanceCountRowState extends ConsumerState<AttendanceCountRow>
    with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _countdownTimer;
  DateTime? _nextAt;
  DateTime? _updatedAt;
  AttendanceCount? _count;
  bool _failed = false;
  bool _busy = false;
  bool _visible = false;
  bool _foreground = true;
  ({int ownerId, int? accountId}) get _pauseScope => (
    ownerId: ref.read(authControllerProvider).profile?.id ?? 0,
    accountId: widget.assistUserId,
  );
  bool get _manuallyPaused => ref
      .read(_pausedCountActivitiesProvider(_pauseScope))
      .containsKey(widget.rollcallId);
  int _revision = 0;

  bool get _active =>
      _visible &&
      _foreground &&
      !widget.expired &&
      !_manuallyPaused &&
      ref.read(authControllerProvider).isSignedIn;
  DateTime get _now => ref.read(attendanceCountClockProvider)();
  bool _canRefresh(AppLifecycleState? state) =>
      state == null ||
      state == AppLifecycleState.resumed ||
      (Theme.of(context).platform == TargetPlatform.windows &&
          state == AppLifecycleState.inactive);
  int get _seconds => ref
      .read(monitorControllerProvider)
      .config
      .effectiveAttendanceIntervalSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _count = ref.read(
      _pausedCountActivitiesProvider(_pauseScope),
    )[widget.rollcallId];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _foreground = _canRefresh(WidgetsBinding.instance.lifecycleState);
    final visible =
        TickerMode.valuesOf(context).enabled &&
        (ShellTabScope.maybeOf(context)?.isActive(AppDestination.rollcall) ??
            true);
    if (_visible != visible) {
      _visible = visible;
      _restart();
    }
  }

  @override
  void didUpdateWidget(AttendanceCountRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rollcallId != widget.rollcallId ||
        oldWidget.assistUserId != widget.assistUserId) {
      _revision++;
      _busy = false;
      _count = ref.read(
        _pausedCountActivitiesProvider(_pauseScope),
      )[widget.rollcallId];
      _nextAt = null;
      _updatedAt = null;
      _failed = false;
      _restart();
    } else if (oldWidget.expired != widget.expired) {
      _restart();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = _canRefresh(state);
    if (_foreground == foreground) return;
    _foreground = foreground;
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    if (_active && !_busy) {
      final delay = _nextAt?.difference(_now) ?? Duration.zero;
      _timer = Timer(delay.isNegative ? Duration.zero : delay, _load);
      _startCountdown();
    }
  }

  void _schedule() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _nextAt = _now.add(Duration(seconds: _seconds));
    if (_active) {
      _timer = Timer(Duration(seconds: _seconds), _load);
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _togglePause() {
    final controller = ref.read(
      _pausedCountActivitiesProvider(_pauseScope).notifier,
    );
    controller.state = _manuallyPaused
        ? ({...controller.state}..remove(widget.rollcallId))
        : {...controller.state, widget.rollcallId: _count};
  }

  Future<void> _load() async {
    if (!mounted || !_active || _busy) return;
    setState(() => _busy = true);
    _nextAt = null;
    final revision = _revision;
    try {
      final result = await ref
          .read(rollcallRepositoryForProvider(widget.assistUserId))
          .fetchAttendanceCount(widget.rollcallId);
      if (!mounted || revision != _revision) return;
      setState(() {
        _count = result;
        _failed = false;
        _updatedAt = _now;
      });
      if (_manuallyPaused) {
        final paused = ref.read(
          _pausedCountActivitiesProvider(_pauseScope).notifier,
        );
        paused.state = {...paused.state, widget.rollcallId: result};
      }
    } catch (_) {
      if (!mounted || revision != _revision) return;
      setState(() => _failed = true);
    } finally {
      if (mounted && revision == _revision) {
        setState(() => _busy = false);
        _schedule();
      }
    }
  }

  @override
  void dispose() {
    _revision++;
    _timer?.cancel();
    _countdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final automaticCountWait = ref.watch(
      _automaticCountWaitProvider(widget.assistUserId),
    );
    final pausedActivities = _pausedCountActivitiesProvider(_pauseScope);
    ref.watch(pausedActivities);
    ref.listen(pausedActivities, (before, after) {
      if ((before?.containsKey(widget.rollcallId) ?? false) ==
          after.containsKey(widget.rollcallId)) {
        return;
      }
      if (!after.containsKey(widget.rollcallId)) _nextAt = null;
      _restart();
    });
    ref.listen(authControllerProvider.select((s) => s.profile?.id), (
      before,
      after,
    ) {
      if (before == after) return;
      _revision++;
      setState(() {
        _count = null;
        _updatedAt = null;
        _nextAt = null;
        _busy = false;
        _failed = false;
      });
      _restart();
    });
    ref.listen(
      monitorControllerProvider.select(
        (s) => s.config.effectiveAttendanceIntervalSeconds,
      ),
      (_, _) => _schedule(),
    );
    final p = AppPalette.of(context);
    final count = _count;
    final remaining = !_active || _nextAt == null
        ? null
        : (_nextAt!.difference(_now).inMilliseconds / 1000).ceil().clamp(
            0,
            _seconds,
          );
    return Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy)
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: p.muted,
                ),
              )
            else
              Icon(Icons.people_outline_rounded, size: 15, color: p.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                count != null
                    ? '已签到人数 ${count.signed} / ${count.total} 人'
                    : widget.expired
                    ? '已签到人数  已结束'
                    : _failed
                    ? '已签到人数  暂不可用'
                    : _manuallyPaused
                    ? '已签到人数  未更新'
                    : '已签到人数  查询中…',
                style: TextStyle(fontSize: 12, height: 1.4, color: p.muted),
              ),
            ),
            if (_failed && count != null) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: _manuallyPaused
                    ? '更新失败，显示上次人数；继续刷新后重试'
                    : '更新失败，显示上次人数；稍后自动重试',
                child: Icon(
                  Icons.sync_problem_rounded,
                  size: 14,
                  color: p.muted,
                ),
              ),
            ],
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_manuallyPaused && !widget.expired)
              Text('已暂停', style: TextStyle(fontSize: 11, color: p.muted))
            else if (_busy)
              Text('刷新中', style: TextStyle(fontSize: 11, color: p.muted))
            else if (remaining != null)
              Tooltip(
                message: _updatedAt == null
                    ? '等待首次更新'
                    : '上次更新 ${_updatedAt!.toLocal().toString().substring(11, 19)}',
                child: Text(
                  '${remaining}s 后刷新',
                  style: TextStyle(fontSize: 11, color: p.muted),
                ),
              ),
            if (!widget.expired && !automaticCountWait)
              IconButton(
                tooltip: _manuallyPaused ? '继续刷新人数' : '暂停刷新人数',
                onPressed: _togglePause,
                icon: Icon(
                  _manuallyPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                ),
                iconSize: 16,
                color: p.muted,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: AppDensity.isTouch(context) ? 44 : 28,
                  height: AppDensity.isTouch(context) ? 44 : 28,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
