import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
import 'package:xmu_rollcall/platform/app_update_installer.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

/// Download completion never opens a modal: only a later foreground transition.
class AppUpdateForegroundPrompt extends ConsumerStatefulWidget {
  const AppUpdateForegroundPrompt({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.installer,
    this.isBusy,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final UpdateInstaller? installer;
  final bool Function()? isBusy;
  static const promptedVersionKey = 'update.prompted.version';

  @override
  ConsumerState<AppUpdateForegroundPrompt> createState() =>
      _AppUpdateForegroundPromptState();
}

class _AppUpdateForegroundPromptState
    extends ConsumerState<AppUpdateForegroundPrompt>
    with WidgetsBindingObserver, WindowListener {
  bool _foreground = true, _presenting = false;
  String? _shownVersion;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (PlatformHooks.isWindows) windowManager.addListener(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (PlatformHooks.isWindows) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _transition(state == AppLifecycleState.resumed);
  @override
  void onWindowFocus() => _transition(true);
  @override
  void onWindowBlur() => _transition(false);
  @override
  void onWindowMinimize() => _transition(false);

  void _transition(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (foreground) unawaited(_prompt());
  }

  bool get _busy =>
      widget.isBusy?.call() ?? ref.read(monitorControllerProvider).starting;

  Future<void> _prompt() async {
    final controller = ref.read(appUpdateControllerProvider);
    final update = controller.downloadedUpdate;
    final navigator = widget.navigatorKey.currentState;
    if (_presenting ||
        update == null ||
        controller.target != UpdateTarget.windows ||
        controller.downloadedFile == null ||
        controller.installing ||
        controller.visibleUpdatePages > 0 ||
        _busy ||
        navigator == null ||
        navigator.canPop() ||
        navigator.userGestureInProgress) {
      return;
    }
    final version = update.version.full;
    if (_shownVersion == version) return;
    _presenting = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted ||
          !_foreground ||
          _busy ||
          controller.visibleUpdatePages > 0 ||
          navigator.canPop() ||
          controller.downloadedUpdate != update ||
          controller.downloadedFile == null ||
          prefs.getString(AppUpdateForegroundPrompt.promptedVersionKey) ==
              version) {
        return;
      }
      final promptContext = navigator.overlay!.context;
      if (!promptContext.mounted) return;
      _shownVersion = version;
      final decision = showAppConfirmDialog(
        promptContext,
        title: '更新已下载',
        message:
            '厦大签到 ${update.version.name} 已下载并校验完成。现在安装将停止检测和值守，退出软件并打开安装程序。',
        confirmLabel: '退出并安装',
        cancelLabel: '稍后',
      );
      await prefs.setString(
        AppUpdateForegroundPrompt.promptedVersionKey,
        version,
      );
      final install = await decision;
      if (!mounted || !install) return;
      try {
        await controller.installReady(widget.installer ?? AppUpdateInstaller());
      } catch (error) {
        if (mounted && promptContext.mounted) {
          AppToast.show(
            promptContext,
            error is UpdateException ? error.message : '未能安装更新，请在关于中重试',
            error: true,
          );
        }
      }
    } finally {
      _presenting = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
