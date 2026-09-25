import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/platform/desktop_shell.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

/// Debug harness for tray + discovery notification (AC-SHELL-06).
///
/// L1 — hide then call production [DesktopShell.notifyRollcallsDiscovered].
/// L2 — arm monitor, hide, after [delay] seed list + real stop/notify path.
abstract final class ShellDebugPreview {
  static Future<void> notifyNow(BuildContext context) async {
    assert(kDebugMode);
    if (!kDebugMode || !PlatformHooks.isDesktop) return;

    AppToast.show(context, '已最小化到托盘，即将发测试通知');
    await DesktopShell.instance.hideToTray();
    // Let hide settle so isVisible is false.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await DesktopShell.instance.notifyRollcallsDiscovered(1);
  }

  static Future<void> scheduleDiscovery(
    BuildContext context,
    WidgetRef ref, {
    Duration delay = const Duration(seconds: 10),
  }) async {
    assert(kDebugMode);
    if (!kDebugMode || !PlatformHooks.isDesktop) return;

    final secs = delay.inSeconds;
    AppToast.show(
      context,
      '$secs 秒后模拟发现签到；已最小化到托盘',
    );
    ref.read(monitorControllerProvider.notifier).debugScheduleDiscovery(
          delay: delay,
        );
    await DesktopShell.instance.hideToTray();
  }
}
