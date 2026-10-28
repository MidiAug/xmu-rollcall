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

/// Idle: 「开始检测」pill. Running: capsule with countdown (tap = pollNow) + stop.
class MonitorQuickControl extends ConsumerStatefulWidget {
  const MonitorQuickControl({
    super.key,
    this.toolbar = false,
    this.prominent = false,
    this.quiet = false,
    this.masthead = false,
  });
  final bool toolbar;
  final bool prominent;
  final bool quiet;
  final bool masthead;

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
      if (!mounted) return;
      final planned = ref.read(selectedDetectionWindowProvider);
      final window = planned.isLoading ? null : planned.valueOrNull;
      final outsideWindow =
          window != null &&
          !window.allows(ref.read(activeRollcallClockProvider)());
      if (ref.read(monitorControllerProvider).running ||
          outsideWindow != _outsideWindow) {
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
    final masthead =
        widget.masthead && Theme.of(context).platform == TargetPlatform.android;
    final monitor = ref.watch(monitorControllerProvider);
    final ctrl = ref.read(monitorControllerProvider.notifier);
    final signedIn = ref.watch(authControllerProvider).isSignedIn;
    final planned = ref.watch(selectedDetectionWindowProvider);
    final window = planned.isLoading ? null : planned.valueOrNull;
    _outsideWindow =
        window != null &&
        !window.allows(ref.read(activeRollcallClockProvider)());

    if (!monitor.running) {
      final enabled =
          signedIn &&
          !monitor.starting &&
          !monitor.loadingSettings &&
          window != null &&
          !_outsideWindow;
      return Align(
        widthFactor: 1,
        heightFactor: 1,
        alignment: Alignment.centerLeft,
        child: AppTooltipAnchor(
          child: Tooltip(
            message: !signedIn
                ? '请先登录'
                : _outsideWindow
                ? todayDetectionRanges(
                    window!,
                    ref.read(activeRollcallClockProvider)(),
                  )
                : '',
            child: AppQuietPill(
              border: masthead ? widget.quiet : !widget.quiet,
              radius: masthead
                  ? 12
                  : widget.toolbar
                  ? 7
                  : 18,
              onTap: enabled
                  ? () async {
                      final plan = ref.read(selectedDetectionWindowProvider);
                      final currentWindow = plan.isLoading
                          ? null
                          : plan.valueOrNull;
                      if (currentWindow == null ||
                          !currentWindow.allows(
                            ref.read(activeRollcallClockProvider)(),
                          )) {
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
                  : null,
              background: masthead
                  ? widget.quiet
                        ? p.selected
                        : enabled
                        ? p.primary
                        : p.controlSurface
                  : widget.quiet
                  ? Colors.transparent
                  : widget.prominent && enabled
                  ? p.primary
                  : widget.toolbar
                  ? p.surface
                  : enabled
                  ? p.selected
                  : p.surfaceHigh,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.detect,
                    size: 16,
                    color: widget.prominent && enabled
                        ? (p.isDark ? p.canvas : Colors.white)
                        : enabled
                        ? p.primary
                        : p.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    monitor.starting ? '启动中…' : '开始检测',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: widget.prominent && enabled
                          ? (p.isDark ? p.canvas : Colors.white)
                          : enabled
                          ? p.primary
                          : p.muted,
                    ),
                  ),
                ],
              ),
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
    final paused = _outsideWindow;
    final label = !monitor.discovering
        ? '自动签到处理中'
        : paused
        ? '等待课表时段'
        : failed
        ? '重试中  ${secs}s'
        : '检测中  ${secs}s';

    final control = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTooltipAnchor(
          child: Tooltip(
            message: !monitor.discovering
                ? '已停止发现新活动，继续处理本轮自动签到'
                : paused
                ? '时段外暂停检测，到时自动恢复'
                : failed
                ? '上次检测失败，点击立即重试'
                : '立即检测一次',
            child: AppQuietPill(
              border: !masthead,
              radius: masthead ? 12 : 18,
              onTap: paused || !monitor.discovering ? null : ctrl.pollNow,
              background: masthead
                  ? Colors.transparent
                  : failed && !paused
                  ? p.danger.withValues(alpha: 0.12)
                  : p.selected,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  color: failed && !paused ? p.danger : p.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        AppTooltipAnchor(
          child: IconButton(
            tooltip: monitor.discovering ? '停止检测' : '停止自动签到',
            visualDensity: masthead
                ? VisualDensity.standard
                : VisualDensity.compact,
            style: masthead
                ? IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.all(12),
                    foregroundColor: p.primary,
                  )
                : null,
            onPressed: ctrl.stop,
            icon: Icon(
              AppIcons.stop,
              color: masthead ? p.primary : p.muted,
              size: 22,
            ),
          ),
        ),
      ],
    );
    return Align(
      widthFactor: 1,
      heightFactor: 1,
      alignment: Alignment.centerLeft,
      child: masthead
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: p.controlSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: control,
            )
          : control,
    );
  }
}
