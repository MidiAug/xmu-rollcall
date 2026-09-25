import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/platform/android_monitor_shell.dart';
import 'package:xmu_rollcall/platform/desktop_shell.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

/// Debug harness for tray / Android discovery notification (AC-SHELL-06 / AC-AND-MON).
abstract final class ShellDebugPreview {
  static Future<void> notifyNow(BuildContext context) async {
    assert(kDebugMode);
    if (!kDebugMode) return;

    if (PlatformHooks.isDesktop) {
      AppToast.show(context, '已最小化到托盘，即将发测试通知');
      await DesktopShell.instance.hideToTray();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await DesktopShell.instance.notifyRollcallsDiscovered(1);
      return;
    }

    if (PlatformHooks.isAndroid) {
      AppToast.show(context, '即将发测试发现通知（请先回桌验证）');
      await AndroidMonitorShell.instance.stopOngoing();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await AndroidMonitorShell.instance.notifyRollcallsDiscovered(1);
      if (!context.mounted) return;
      AppToast.show(
        context,
        '若仍在前台则按设计不弹发现通知；请回桌后用「10s 模拟」',
      );
    }
  }

  static Future<void> scheduleDiscovery(
    BuildContext context,
    WidgetRef ref, {
    Duration delay = const Duration(seconds: 10),
  }) async {
    assert(kDebugMode);
    if (!kDebugMode) return;

    final secs = delay.inSeconds;
    if (PlatformHooks.isDesktop) {
      AppToast.show(
        context,
        '$secs 秒后模拟发现签到；已最小化到托盘',
      );
      ref.read(monitorControllerProvider.notifier).debugScheduleDiscovery(
            delay: delay,
          );
      await DesktopShell.instance.hideToTray();
      return;
    }

    if (PlatformHooks.isAndroid) {
      AppToast.show(
        context,
        '$secs 秒后模拟发现；请尽快回桌以验证通知',
      );
      ref.read(monitorControllerProvider.notifier).debugScheduleDiscovery(
            delay: delay,
          );
    }
  }
}
