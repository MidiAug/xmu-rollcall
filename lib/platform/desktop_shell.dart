import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xmu_rollcall/app/app_brand.dart';
import 'package:xmu_rollcall/app/close_ask_dialog.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/shell_navigation.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/settings/close_prefs_controller.dart';
import 'package:xmu_rollcall/platform/close_prefs.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';
import 'package:xmu_rollcall/platform/desktop_notifications.dart';
import 'package:xmu_rollcall/platform/windows_desktop_notifications.dart';

/// Desktop window close / tray / discovery notification (Phase 3 shell slice).
class DesktopShell with WindowListener, TrayListener {
  DesktopShell._() {
    notifications = DesktopNotifications(
      setup: _setupNotifications,
      isForeground: () async =>
          await windowManager.isVisible() &&
          !await windowManager.isMinimized() &&
          await windowManager.isFocused(),
      send: _sendNotification,
      sendQuiet: (body) => _sendNotification(body, false, silent: true),
      showInApp: (body) {
        final overlay = navigatorKey?.currentState?.overlay;
        if (overlay == null || !overlay.mounted) return false;
        AppToast.show(overlay.context, body, targetOverlay: overlay);
        return true;
      },
    );
  }

  static final DesktopShell instance = DesktopShell._();

  static const discoveryNotificationId =
      WindowsDesktopNotifications.discoveryPayload;
  static const testNotificationId = WindowsDesktopNotifications.testPayload;
  late final DesktopNotifications notifications;
  final trayAvailable = ValueNotifier(false);
  LocalNotification? _discoveryNotification;
  LocalNotification? _testNotification;
  FlutterLocalNotificationsWindows? _windowsNotifications;
  Future<void>? _initializing;
  bool _quitting = false;

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
    return _initializing ??= _init().whenComplete(() => _initializing = null);
  }

  Future<void> _init() async {
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    await notifications.initialize();

    try {
      await _setupTray();
      trayManager.addListener(this);
      trayAvailable.value = true;
    } catch (e, st) {
      AppLog.logAppError(error: e, stackTrace: st, source: 'desktop_tray');
    }

    PlatformHooks.onRollcallsDiscovered = notifyRollcallsDiscovered;
    PlatformHooks.onAutomaticAnswerResult = (courseTitle, ok) async {
      if (!await notifications.notifyResult(courseTitle, ok)) {
        throw StateError('桌面签到结果通知发送失败');
      }
    };
    _ready = true;
    AppLog.event(
      'shell.desktop_ready',
      fields: {
        'notificationsReady': notifications.ready,
        'trayReady': trayAvailable.value,
      },
    );
  }

  Future<void> _setupTray() async {
    final icon = Platform.isWindows
        ? 'assets/tray/tray_icon.ico'
        : 'assets/tray/tray_icon.png';
    await trayManager.setIcon(icon);
    await trayManager.setToolTip(kAppDisplayName);
    await updateTrayMenu();
  }

  Future<void> _setupNotifications() async {
    if (!Platform.isWindows) {
      await localNotifier.setup(
        appName: kAppDisplayName,
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      return;
    }
    // local_notifier's Windows implementation reports success even if WinToast
    // rejects a toast. This backend propagates native initialization/show errors.
    // The native plugin owns late-final handles. Never reinitialize an old
    // instance after failure/disposal; a fresh instance keeps retries usable.
    _windowsNotifications?.dispose();
    _windowsNotifications = null;
    final plugin = FlutterLocalNotificationsWindows();
    final initialized = await WindowsDesktopNotifications(plugin: plugin)
        .initialize(
          (response) => _run(handleNotificationActivation(response.payload)),
        );
    if (!initialized) throw StateError('Windows 通知初始化失败');
    _windowsNotifications = plugin;
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _run(handleNotificationActivation(launch?.notificationResponse?.payload));
    }
  }

  /// Test notifications restore the current page; discoveries open the list.
  Future<void> handleNotificationActivation(String? payload) =>
      payload == testNotificationId
      ? showMainWindow()
      : showRollcallFromNotification();

  Future<void> updateTrayMenu() async {
    final running = isMonitorRunning?.call() ?? false;
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示窗口'),
          MenuItem(key: 'rollcalls', label: '查看签到'),
          MenuItem(key: 'stop', label: '停止检测', disabled: !running),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: '退出'),
        ],
      ),
    );
  }

  Future<void> showMainWindow() async {
    if (await windowManager.isMinimized()) await windowManager.restore();
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
    if (!trayAvailable.value) {
      AppLog.event('shell.tray_unavailable', level: 'W');
      await windowManager.minimize();
      return;
    }
    AppLog.event('shell.hide_tray');
    await windowManager.hide();
  }

  Future<void> quitApp({bool stopPolling = false}) async {
    if (_quitting) return;
    _quitting = true;
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
      _windowsNotifications?.dispose();
      await _discoveryNotification?.destroy();
      await _testNotification?.destroy();
      await trayManager.destroy();
    } catch (_) {}
    // Windows: destroy() inside CloseRequested freezes for seconds/minutes
    // (leanflutter/window_manager#502). Clear preventClose then close().
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  /// Called for new discoveries while monitoring continues.
  Future<void> notifyRollcallsDiscovered(int count) async {
    if (!PlatformHooks.isDesktop || count <= 0) return;
    if (!await notifications.notify(count)) throw StateError('桌面通知发送失败');
    AppLog.event('shell.notify_found', fields: {'count': count});
  }

  Future<void> _sendNotification(
    String body,
    bool test, {
    bool silent = false,
  }) async {
    if (Platform.isWindows) {
      final plugin = _windowsNotifications;
      if (plugin == null) throw StateError('Windows 通知尚未初始化');
      await WindowsDesktopNotifications(
        plugin: plugin,
      ).show(body, test: test, silent: silent);
      return;
    }
    final notification = test
        ? (_testNotification ??= LocalNotification(
            identifier: testNotificationId,
            title: kAppDisplayName,
          ))
        : (_discoveryNotification ??= LocalNotification(
            identifier: discoveryNotificationId,
            title: kAppDisplayName,
          ));
    notification.body = body;
    // LocalNotification already owns a listener: register one click handler only.
    notification.onClick = () =>
        _run(test ? showMainWindow() : showRollcallFromNotification());
    await notification.show();
  }

  void _run(Future<void> operation) {
    unawaited(
      operation.catchError((Object error, StackTrace stack) {
        AppLog.logAppError(
          error: error,
          stackTrace: stack,
          source: 'desktop_shell',
        );
      }),
    );
  }

  @override
  void onWindowEvent(String eventName) {
    if (const {'focus', 'blur', 'minimize', 'restore'}.contains(eventName)) {
      AppLog.event('shell.window', level: 'D', fields: {'state': eventName});
    }
  }

  @override
  void onWindowClose() {
    // Keep sync; async work is scheduled so we never block the platform channel.
    if (_handlingClose) return;
    _handlingClose = true;
    _run(_handleCloseRequested().whenComplete(() => _handlingClose = false));
  }

  Future<void> _handleCloseRequested() async {
    // Second pass after quitApp cleared preventClose — allow native close.
    if (!await windowManager.isPreventClose()) return;

    final prefs = readPrefs?.call() ?? const ClosePrefs();
    final busy = isMonitorRunning?.call() ?? false;
    AppLog.event(
      'shell.close_requested',
      fields: {'busy': busy, 'mode': prefs.mode.name},
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
      return const CloseAskResult(action: CloseAskAction.tray, remember: false);
    }
    return showCloseAskDialog(
      ctx,
      busy: busy,
      rememberDefaultChecked: prefs.rememberCheckboxDefault,
    );
  }

  @override
  void onTrayIconMouseDown() {
    _run(showMainWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    _run(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _run(showMainWindow());
      case 'rollcalls':
        _run(showRollcallFromNotification());
      case 'stop':
        stopMonitor?.call();
      case 'quit':
        _run(quitApp(stopPolling: true));
      default:
        break;
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
      DesktopShell.instance._run(DesktopShell.instance.init());
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
    shell.isMonitorRunning = () => ref.read(monitorControllerProvider).running;
    shell.stopMonitor = () =>
        ref.read(monitorControllerProvider.notifier).stop();
    shell.readPrefs = () => ref.read(closePrefsProvider);
    shell.applyAskChoice = ({required toTray, required remember}) {
      return ref
          .read(closePrefsProvider.notifier)
          .applyAskChoice(toTray: toTray, remember: remember);
    };
  }

  @override
  Widget build(BuildContext context) {
    // Keep prefs / monitor identity warm so close handler sees latest.
    ref.watch(closePrefsProvider);
    ref.watch(monitorControllerProvider.select((s) => s.running));
    ref.listen(monitorControllerProvider.select((s) => s.running), (_, _) {
      if (DesktopShell.instance.trayAvailable.value) {
        DesktopShell.instance._run(DesktopShell.instance.updateTrayMenu());
      }
    });
    _wire();
    return widget.child;
  }

  @override
  void dispose() {
    final shell = DesktopShell.instance;
    if (shell.navigatorKey == widget.navigatorKey) {
      shell.navigatorKey = null;
      shell.isMonitorRunning = null;
      shell.stopMonitor = null;
      shell.readPrefs = null;
      shell.applyAskChoice = null;
    }
    super.dispose();
  }
}
