import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'course_watch.dart';
import 'detection_window.dart';
import 'detection_window_setting.dart';
import 'monitor_controller.dart';

String _startLabel(DateTime next, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final date = DateTime(next.year, next.month, next.day);
  final prefix = date == today
      ? '今日'
      : date == tomorrow
      ? '明天'
      : '${next.month}月${next.day}日';
  return '$prefix ${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')} 开始检测';
}

/// Present the engine's plan; never schedule a second discovery from the UI.
String monitorStatusText({
  required MonitorState monitor,
  required DateTime now,
  required String fallback,
  DetectionWindow? window,
  int pendingCount = 0,
  int completedCount = 0,
}) {
  if (!monitor.running) {
    if (pendingCount > 0) return '有 $pendingCount 项待签到';
    if (completedCount > 0) return '当前签到已完成';
    return fallback;
  }
  if (!monitor.discovering) return monitor.activityMessage ?? '正在处理自动签到';
  final plan = monitor.config.courseWatch ? monitor.discoveryWindow : window;
  if (monitor.waitingForWindow || (plan != null && !plan.allows(now))) {
    if (plan == null) return '值守中，等待课表时段';
    if (!plan.scheduleBased && plan.intervals == null) {
      return '等待检测时段，${_startLabel(plan.nextStart(now), now)}';
    }
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final ranges = plan.intervals ?? const <WatchRange>[];
    final hasToday = ranges.any(
      (r) => r.end.isAfter(today) && r.start.isBefore(tomorrow),
    );
    String label;
    if (plan is CourseWatchWindow && plan.completedToday) {
      label = '今日值守已完成';
    } else if (!plan.hasSchedule) {
      label = '暂无可检测的课表安排';
    } else if (plan is CourseWatchWindow ? !plan.hasLessonsToday : !hasToday) {
      label = '今日无检测安排';
    } else if (!ranges.any(
      (r) => r.end.isAfter(now) && r.start.isBefore(tomorrow),
    )) {
      label = '今日检测时段已结束';
    } else {
      label = completedCount > 0 && monitor.config.courseWatch
          ? '签到已完成，继续值守'
          : monitor.config.courseWatch
          ? '值守中'
          : '等待课表时段';
    }
    if (pendingCount > 0) label = '有 $pendingCount 项待签到';
    final next = ranges.where((r) => r.start.isAfter(now)).firstOrNull?.start;
    if (next == null) return '$label，等待后续安排';
    return '$label，${_startLabel(next, now)}';
  }
  final next = monitor.nextPollAt;
  final seconds = next == null
      ? 0
      : (next.difference(now).inMilliseconds / 1000).ceil().clamp(0, 86400);
  final action = monitor.consecutiveFailures > 0 ? '重试' : '再次检测';
  final progress = seconds > 0
      ? '$seconds 秒后$action'
      : '正在${monitor.consecutiveFailures > 0 ? '重试' : '检测'}';
  final prefix = pendingCount > 0
      ? '有 $pendingCount 项待签到'
      : monitor.consecutiveFailures > 0
      ? '检测失败'
      : '检测中';
  return seconds == 0 && pendingCount == 0 && monitor.consecutiveFailures == 0
      ? progress
      : '$prefix，$progress';
}

class MonitorStatusLine extends ConsumerStatefulWidget {
  const MonitorStatusLine({
    super.key,
    required this.fallback,
    this.overrideMessage,
    this.warning = false,
    this.pendingCount = 0,
    this.completedCount = 0,
  });
  final String fallback;
  final String? overrideMessage;
  final int pendingCount, completedCount;
  final bool warning;

  @override
  ConsumerState<MonitorStatusLine> createState() => _MonitorStatusLineState();
}

class _MonitorStatusLineState extends ConsumerState<MonitorStatusLine> {
  Timer? _tick;
  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          TickerMode.valuesOf(context).enabled &&
          ref.read(monitorControllerProvider).running) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monitor = ref.watch(monitorControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final p = AppPalette.of(context);
    final color =
        widget.warning ||
            (widget.overrideMessage == null &&
                monitor.running &&
                !monitor.waitingForWindow &&
                monitor.consecutiveFailures > 0)
        ? p.danger
        : monitor.running || widget.pendingCount > 0
        ? p.primary
        : widget.completedCount > 0
        ? p.successAccent
        : p.muted;
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.overrideMessage ??
                (!auth.isSignedIn ? '登录后可检测签到' : null) ??
                monitorStatusText(
                  monitor: monitor,
                  now: ref.read(activeRollcallClockProvider)(),
                  fallback: widget.fallback,
                  window: monitor.config.courseWatch
                      ? null
                      : ref.watch(selectedDetectionWindowProvider).valueOrNull,
                  pendingCount: widget.pendingCount,
                  completedCount: widget.completedCount,
                ),
            key: const ValueKey('monitor-status-line'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: color,
              height: 1.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
