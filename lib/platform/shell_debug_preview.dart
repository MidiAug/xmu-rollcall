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
      await DesktopShell.instance.notifications.test();
      return;
    }

    if (PlatformHooks.isAndroid) {
      final ok = await AndroidMonitorShell.instance.testNotification();
      if (!context.mounted) return;
      AppToast.show(
        context,
        ok ? '测试通知已发送，请确认声音和震动' : '测试通知失败，请检查通知权限和诊断日志',
        error: !ok,
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
      AppToast.show(context, '$secs 秒后模拟发现签到；已最小化到托盘');
      ref
          .read(monitorControllerProvider.notifier)
          .debugScheduleDiscovery(delay: delay);
      await DesktopShell.instance.hideToTray();
      return;
    }

    if (PlatformHooks.isAndroid) {
      final ok = await AndroidMonitorShell.instance.scheduleDiagnostic(delay);
      if (!context.mounted) return;
      AppToast.show(
        context,
        ok ? '$secs 秒后由后台服务发送测试通知；可回桌或锁屏' : '后台测试启动失败，请检查诊断日志',
        error: !ok,
      );
    }
  }
}
