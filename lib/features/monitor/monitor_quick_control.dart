import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/settings/notification_settings_page.dart';

/// Idle: 「开始检测」pill. Running: capsule with countdown (tap = pollNow) + stop.
class MonitorQuickControl extends ConsumerStatefulWidget {
  const MonitorQuickControl({super.key, this.toolbar = false});
  final bool toolbar;

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
      final window = ref.read(detectionWindowProvider);
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
    final monitor = ref.watch(monitorControllerProvider);
    final ctrl = ref.read(monitorControllerProvider.notifier);
    final signedIn = ref.watch(authControllerProvider).isSignedIn;
    final window = ref.watch(detectionWindowProvider);
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
        alignment: Alignment.centerLeft,
        child: AppTooltipAnchor(
          child: Tooltip(
            message: !signedIn
                ? '请先登录'
                : _outsideWindow
                ? '检测时段为 ${window!.label}'
                : '',
            child: AppQuietPill(
              radius: widget.toolbar ? 7 : 18,
              onTap: enabled
                  ? () async {
                      final currentWindow = ref.read(detectionWindowProvider);
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
              background: widget.toolbar
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
                    color: enabled ? p.primary : p.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    monitor.starting ? '启动中…' : '开始检测',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: enabled ? p.primary : p.muted,
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
        ? '${DetectionWindow.formatMinute(window!.startMinute)} 继续'
        : failed
        ? '重试中  ${secs}s'
        : '检测中  ${secs}s';

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
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
                onTap: paused || !monitor.discovering ? null : ctrl.pollNow,
                background: failed && !paused
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
              visualDensity: VisualDensity.compact,
              onPressed: ctrl.stop,
              icon: Icon(AppIcons.stop, color: p.muted, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
