import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository_providers.dart';

/// Poll only while the card is visible and the app is in the foreground.
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
  int _revision = 0;

  bool get _active => _visible && _foreground && !widget.expired;
  int get _seconds => ref
      .read(monitorControllerProvider)
      .config
      .effectiveAttendanceIntervalSeconds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      _count = null;
      _failed = false;
      _restart();
    } else if (oldWidget.expired != widget.expired) {
      _restart();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _nextAt = null;
    if (_active && !_busy) {
      _timer = Timer(Duration.zero, _load);
    }
  }

  void _schedule() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _nextAt = null;
    if (_active) {
      _nextAt = DateTime.now().add(Duration(seconds: _seconds));
      _timer = Timer(Duration(seconds: _seconds), _load);
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
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
        _updatedAt = DateTime.now();
      });
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
    ref.listen(
      monitorControllerProvider.select(
        (s) => s.config.effectiveAttendanceIntervalSeconds,
      ),
      (_, _) => _schedule(),
    );
    final p = AppPalette.of(context);
    final count = _count;
    final remaining = _nextAt == null
        ? null
        : (_nextAt!.difference(DateTime.now()).inMilliseconds / 1000)
              .ceil()
              .clamp(0, _seconds);
    return Row(
      children: [
        if (_busy)
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: p.muted),
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
                : '已签到人数  查询中…',
            style: TextStyle(fontSize: 12, height: 1.4, color: p.muted),
          ),
        ),
        if (_failed && count != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: '更新失败，显示上次人数；稍后自动重试',
            child: Icon(Icons.sync_problem_rounded, size: 14, color: p.muted),
          ),
        ],
        const SizedBox(width: 8),
        if (_busy)
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
      ],
    );
  }
}
