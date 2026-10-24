import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/desktop_shell_chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';

/// Checks live editor state before the shell discards a tab's route stack.
class ShellTabExitController {
  final _guards = <AppDestination, Map<Object, _ShellTabExitGuardState>>{};

  Future<bool> canLeave(BuildContext context, AppDestination tab) async {
    Iterable<ShellTabExitGuard> guards() =>
        (_guards[tab]?.values ?? const <_ShellTabExitGuardState>[])
            .where((g) => g.mounted && (g._route?.isActive ?? true))
            .map((g) => g.widget);
    if (guards().any((g) => g.isBusy?.call() ?? false)) {
      AppToast.show(context, '正在处理，请稍候再切换页面');
      return false;
    }
    if (!guards().any((g) => g.hasUnsavedChanges?.call() ?? false)) return true;
    final discard = await showAppConfirmDialog(
      context,
      title: '放弃未保存的修改？',
      message: '离开后，这些修改不会保留。',
      cancelLabel: '继续编辑',
      confirmLabel: '放弃并离开',
    );
    return discard && !guards().any((g) => g.isBusy?.call() ?? false);
  }
}

class ShellTabExitScope extends InheritedWidget {
  const ShellTabExitScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final ShellTabExitController controller;

  @override
  bool updateShouldNotify(ShellTabExitScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Editors outside the tab shell keep their existing navigation behavior.
class ShellTabExitGuard extends StatefulWidget {
  const ShellTabExitGuard({
    super.key,
    this.hasUnsavedChanges,
    this.isBusy,
    required this.child,
  });
  final bool Function()? hasUnsavedChanges;
  final bool Function()? isBusy;
  final Widget child;

  @override
  State<ShellTabExitGuard> createState() => _ShellTabExitGuardState();
}

class _ShellTabExitGuardState extends State<ShellTabExitGuard> {
  ShellTabExitController? _controller;
  AppDestination? _tab;
  ModalRoute<dynamic>? _route;

  void _release() {
    _controller?._guards[_tab]?.remove(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _release();
    _controller = context
        .dependOnInheritedWidgetOfExactType<ShellTabExitScope>()
        ?.controller;
    _tab = ShellTabDestination.maybeOf(context);
    _route = ModalRoute.of(context);
    _register();
  }

  void _register() {
    if (_tab == null || _controller == null) return;
    (_controller!._guards[_tab!] ??= {})[this] = this;
  }

  @override
  void didUpdateWidget(covariant ShellTabExitGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
