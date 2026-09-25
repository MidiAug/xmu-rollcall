import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xmu_rollcall/app/app_brand.dart';
import 'package:xmu_rollcall/app/close_ask_dialog.dart';
import 'package:xmu_rollcall/app/shell_navigation.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/settings/close_prefs_controller.dart';
import 'package:xmu_rollcall/platform/close_prefs.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

/// Desktop window close / tray / discovery notification (Phase 3 shell slice).
class DesktopShell with WindowListener, TrayListener, LocalNotificationListener {
  DesktopShell._();

  static final DesktopShell instance = DesktopShell._();

  static const discoveryNotificationId = 'rollcall-found';

  GlobalKey<NavigatorState>? navigatorKey;
  bool Function()? isMonitorRunning;
  VoidCallback? stopMonitor;
  ClosePrefs Function()? readPrefs;
  Future<void> Function({required bool toTray, required bool remember})?
      applyAskChoice;

  var _ready = false;
  var _handlingClose = false;

  Future<void> init() async {
    if (!PlatformHooks.isDesktop || _ready) return;

    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    try {
      await localNotifier.setup(
        appName: kAppDisplayName,
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      localNotifier.addListener(this);
    } catch (e, st) {
      AppLog.logAppError(error: e, stackTrace: st, source: 'desktop_notify');
    }

    try {
      await _setupTray();
      trayManager.addListener(this);
    } catch (e, st) {
      AppLog.logAppError(error: e, stackTrace: st, source: 'desktop_tray');
    }

    PlatformHooks.onRollcallsDiscovered = notifyRollcallsDiscovered;
    _ready = true;
    AppLog.event('shell.desktop_ready', fields: {'ok': true});
  }

  Future<void> _setupTray() async {
    final icon = Platform.isWindows
        ? 'assets/tray/tray_icon.ico'
        : 'assets/tray/tray_icon.png';
    await trayManager.setIcon(icon);
    await trayManager.setToolTip(kAppDisplayName);
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示窗口'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '退出'),
        ],
      ),
    );
  }

  Future<void> showMainWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Restore window and land on the rollcall hub list.
  Future<void> showRollcallFromNotification() async {
    await showMainWindow();
    // Wait a frame so AdaptiveShell is mounted after show.
    await Future<void>.delayed(Duration.zero);
    ShellNavigation.instance.openRollcall(popToRoot: true);
  }

  Future<void> hideToTray() async {
    AppLog.event('shell.hide_tray');
    await windowManager.hide();
  }

  Future<void> quitApp({bool stopPolling = false}) async {
    AppLog.event('shell.quit', fields: {'stopPolling': stopPolling});
    if (stopPolling) {
      try {
        stopMonitor?.call();
      } catch (_) {}
    }
    try {
      await AppLog.flush();
    } catch (_) {}
    try {
      await trayManager.destroy();
    } catch (_) {}
    // Windows: destroy() inside CloseRequested freezes for seconds/minutes
    // (leanflutter/window_manager#502). Clear preventClose then close().
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  /// Called when main monitor discovers ongoing rollcalls and stops.
  Future<void> notifyRollcallsDiscovered(int count) async {
    if (!PlatformHooks.isDesktop || count <= 0) return;
    try {
      final visible = await windowManager.isVisible();
      if (visible) return;
      final n = LocalNotification(
        identifier: discoveryNotificationId,
        title: kAppDisplayName,
        body: '发现进行中签到 $count 条，检测已停止',
      );
      n.onClick = showRollcallFromNotification;
      await n.show();
      AppLog.event('shell.notify_found', fields: {'count': count});
    } catch (e, st) {
      AppLog.logAppError(error: e, stackTrace: st, source: 'desktop_notify');
    }
  }

  @override
  void onWindowClose() {
    // Keep sync; async work is scheduled so we never block the platform channel.
    if (_handlingClose) return;
    _handlingClose = true;
    _handleCloseRequested().whenComplete(() => _handlingClose = false);
  }

  Future<void> _handleCloseRequested() async {
    // Second pass after quitApp cleared preventClose — allow native close.
    if (!await windowManager.isPreventClose()) return;

    final prefs = readPrefs?.call() ?? const ClosePrefs();
    final busy = isMonitorRunning?.call() ?? false;
    AppLog.event(
      'shell.close_requested',
      fields: {
        'busy': busy,
        'mode': prefs.mode.name,
      },
    );

    if (busy) {
      if (prefs.closePrefSet && prefs.closeToTray) {
        await hideToTray();
        return;
      }
      final result = await _showAsk(busy: true, prefs: prefs);
      if (result == null) {
        AppLog.event('shell.close_dismissed', fields: {'busy': true});
        return;
      }
      if (result.action == CloseAskAction.tray) {
        await hideToTray();
      } else {
        await quitApp(stopPolling: true);
      }
      return;
    }

    if (!prefs.closePrefSet) {
      final result = await _showAsk(busy: false, prefs: prefs);
      if (result == null) {
        AppLog.event('shell.close_dismissed', fields: {'busy': false});
        return;
      }
      final toTray = result.action == CloseAskAction.tray;
      await applyAskChoice?.call(toTray: toTray, remember: result.remember);
      if (toTray) {
        await hideToTray();
      } else {
        await quitApp();
      }
      return;
    }

    if (prefs.closeToTray) {
      await hideToTray();
    } else {
      await quitApp();
    }
  }

  Future<CloseAskResult?> _showAsk({
    required bool busy,
    required ClosePrefs prefs,
  }) async {
    final ctx = navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) {
      return const CloseAskResult(
        action: CloseAskAction.tray,
        remember: false,
      );
    }
    return showCloseAskDialog(
      ctx,
      busy: busy,
      rememberDefaultChecked: prefs.rememberCheckboxDefault,
    );
  }

  @override
  void onTrayIconMouseDown() {
    showMainWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        showMainWindow();
      case 'quit':
        quitApp(stopPolling: true);
      default:
        break;
    }
  }

  @override
  void onLocalNotificationClick(LocalNotification notification) {
    if (notification.identifier == discoveryNotificationId) {
      showRollcallFromNotification();
    } else {
      showMainWindow();
    }
  }
}

/// Binds [DesktopShell] callbacks to Riverpod and keeps [navigatorKey] fresh.
class DesktopShellBinder extends ConsumerStatefulWidget {
  const DesktopShellBinder({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<DesktopShellBinder> createState() => _DesktopShellBinderState();
}

class _DesktopShellBinderState extends ConsumerState<DesktopShellBinder> {
  @override
  void initState() {
    super.initState();
    _wire();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DesktopShell.instance.init();
    });
  }

  @override
  void didUpdateWidget(covariant DesktopShellBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _wire();
  }

  void _wire() {
    final shell = DesktopShell.instance;
    shell.navigatorKey = widget.navigatorKey;
    shell.isMonitorRunning =
        () => ref.read(monitorControllerProvider).running;
    shell.stopMonitor =
        () => ref.read(monitorControllerProvider.notifier).stop();
    shell.readPrefs = () => ref.read(closePrefsProvider);
    shell.applyAskChoice = ({required toTray, required remember}) {
      return ref.read(closePrefsProvider.notifier).applyAskChoice(
            toTray: toTray,
            remember: remember,
          );
    };
  }

  @override
  Widget build(BuildContext context) {
    // Keep prefs / monitor identity warm so close handler sees latest.
    ref.watch(closePrefsProvider);
    ref.watch(monitorControllerProvider.select((s) => s.running));
    _wire();
    return widget.child;
  }
}
