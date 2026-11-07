import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/detection_window_setting.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/settings/notification_settings_page.dart';

enum MonitorControlStyle {
  standard,
  prominent,
  quiet,
  toolbar,
  masthead,
  mastheadQuiet,
  mastheadStatus,
}

/// Start/stop actions stay separate from the page status line.
class MonitorQuickControl extends ConsumerStatefulWidget {
  const MonitorQuickControl({
    super.key,
    this.style = MonitorControlStyle.standard,
  });
  final MonitorControlStyle style;

  @override
  ConsumerState<MonitorQuickControl> createState() =>
      _MonitorQuickControlState();
}

class _MonitorQuickControlState extends ConsumerState<MonitorQuickControl> {
  Timer? _tick;
  bool _outsideWindow = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      final monitor = ref.read(monitorControllerProvider);
      if (monitor.running) {
        if (widget.style == MonitorControlStyle.mastheadStatus &&
            Theme.of(context).platform == TargetPlatform.android &&
            monitor.discovering &&
            !monitor.waitingForWindow) {
          setState(() {});
        }
        return;
      }
      if (monitor.config.courseWatch) return;
      final planned = ref.read(selectedDetectionWindowProvider);
      final window = planned.isLoading ? null : planned.valueOrNull;
      final outsideWindow =
          window != null &&
          !window.allows(ref.read(activeRollcallClockProvider)());
      if (outsideWindow != _outsideWindow) {
        setState(() => _outsideWindow = outsideWindow);
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
    final p = AppPalette.of(context);
    final style = widget.style;
    final toolbar = style == MonitorControlStyle.toolbar;
    final quiet =
        style == MonitorControlStyle.quiet ||
        style == MonitorControlStyle.mastheadQuiet;
    final prominent = style == MonitorControlStyle.prominent;
    final masthead =
        (style == MonitorControlStyle.masthead ||
            style == MonitorControlStyle.mastheadQuiet ||
            style == MonitorControlStyle.mastheadStatus) &&
        Theme.of(context).platform == TargetPlatform.android;
    final statusOnly = masthead && style == MonitorControlStyle.mastheadStatus;
    final mastheadStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: p.border),
      backgroundColor: p.surface.withValues(alpha: .8),
    );
    final monitor = ref.watch(
      monitorControllerProvider.select(
        (s) => (
          running: s.running,
          starting: s.starting,
          loadingSettings: s.loadingSettings,
          courseWatch: s.config.courseWatch,
          nextPollAt: statusOnly ? s.nextPollAt : null,
          consecutiveFailures: statusOnly ? s.consecutiveFailures : 0,
          waitingForWindow: statusOnly && s.waitingForWindow,
          discovering: !statusOnly || s.discovering,
        ),
      ),
    );
    final ctrl = ref.read(monitorControllerProvider.notifier);
    final signedIn = ref.watch(
      authControllerProvider.select((s) => s.isSignedIn),
    );
    final planned = ref.watch(selectedDetectionWindowProvider);
    final window = planned.isLoading ? null : planned.valueOrNull;
    _outsideWindow =
        window != null &&
        !window.allows(ref.read(activeRollcallClockProvider)());

    if (!monitor.running) {
      if (statusOnly) return const SizedBox.shrink();
      final enabled =
          signedIn &&
          !monitor.starting &&
          !monitor.loadingSettings &&
          (monitor.courseWatch || (window != null && !_outsideWindow));
      final onStart = enabled
          ? () async {
              final plan = ref.read(selectedDetectionWindowProvider);
              final currentWindow = plan.isLoading ? null : plan.valueOrNull;
              if (!monitor.courseWatch &&
                  (currentWindow == null ||
                      !currentWindow.allows(
                        ref.read(activeRollcallClockProvider)(),
                      ))) {
                return;
              }
              final r = await ctrl.startAsync();
              if (!context.mounted) return;
              switch (r) {
                case StartMonitorResult.started:
                  await showBackgroundReminderSetup(context);
                case StartMonitorResult.notificationDenied:
                  AppToast.show(context, '需要通知权限才能在后台检测', error: true);
                  await showBackgroundReminderSetup(context);
                case StartMonitorResult.fgsFailed:
                  AppToast.show(context, '无法启动后台检测通知', error: true);
                default:
                  break;
              }
            }
          : null;
      final content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            monitor.courseWatch ? AppIcons.guard : AppIcons.detect,
            size: 16,
            color: prominent && !masthead && enabled
                ? (p.isDark ? p.canvas : Colors.white)
                : enabled
                ? p.ink
                : p.muted,
          ),
          const SizedBox(width: 6),
          Text(
            monitor.courseWatch ? '开始值守' : '开始检测',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: prominent && !masthead && enabled
                  ? (p.isDark ? p.canvas : Colors.white)
                  : enabled
                  ? p.ink
                  : p.muted,
            ),
          ),
        ],
      );
      if (masthead) {
        return OutlinedButton(
          onPressed: onStart,
          style: mastheadStyle,
          child: content,
        );
      }
      return Align(
        widthFactor: 1,
        heightFactor: 1,
        alignment: Alignment.centerLeft,
        child: AppTooltipAnchor(
          child: Tooltip(
            message: !signedIn
                ? '请先登录'
                : _outsideWindow && !monitor.courseWatch
                ? todayDetectionRanges(
                    window!,
                    ref.read(activeRollcallClockProvider)(),
                  )
                : '',
            child: AppQuietPill(
              border: masthead || !quiet,
              radius: masthead
                  ? 12
                  : toolbar
                  ? 7
                  : 18,
              onTap: onStart,
              background: masthead
                  ? p.surface.withValues(alpha: .8)
                  : quiet
                  ? Colors.transparent
                  : prominent && enabled
                  ? p.primary
                  : enabled
                  ? p.surface
                  : p.surfaceHigh,
              child: content,
            ),
          ),
        ),
      );
    }

    final next = monitor.nextPollAt;
    final secs = next == null
        ? 0
        : next.difference(DateTime.now()).inSeconds.clamp(0, 9999);
    final failed = monitor.consecutiveFailures > 0;
    final paused = monitor.waitingForWindow || _outsideWindow;
    final label = !monitor.discovering
        ? '自动签到处理中'
        : paused
        ? '等待课表时段'
        : failed
        ? (masthead ? '重试中 $secs s' : '重试中  ${secs}s')
        : (masthead ? '检测中 $secs s' : '检测中  ${secs}s');

    if (masthead) {
      if (statusOnly) {
        final color = failed && !paused ? p.danger : p.muted;
        return Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: SizedBox(
                key: const ValueKey('monitor-countdown-width'),
                width: double.infinity,
                child: Text(
                  label,
                  key: const ValueKey('android-detection-status'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        );
      }
      return OutlinedButton(
        onPressed: ctrl.stop,
        style: mastheadStyle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              monitor.courseWatch ? AppIcons.guardPaused : AppIcons.stopSolid,
              size: 16,
              color: p.ink,
            ),
            const SizedBox(width: 6),
            Text(
              monitor.courseWatch ? '暂停值守' : '停止检测',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: p.ink,
              ),
            ),
          ],
        ),
      );
    }
    return AppQuietPill(
      border: !quiet,
      radius: toolbar ? 7 : 18,
      background: quiet ? Colors.transparent : p.surface,
      onTap: ctrl.stop,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            monitor.courseWatch ? AppIcons.guardPaused : AppIcons.stopSolid,
            size: 16,
            color: p.ink,
          ),
          const SizedBox(width: 6),
          Text(
            monitor.courseWatch ? '暂停值守' : '停止检测',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: p.ink,
            ),
          ),
        ],
      ),
    );
  }
}
