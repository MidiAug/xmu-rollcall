import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/destinations.dart';

/// Shell → tab pages: which destination is visible, and re-tap signals.
///
/// Root pages stay in [IndexedStack]; leaving discards nested routes, and
/// selecting a tab restores its root scroll position and temporary UI.
class ShellTabScope extends InheritedWidget {
  const ShellTabScope({
    super.key,
    required this.current,
    required this.retapEpoch,
    required this.retapDestination,
    required super.child,
  });

  final AppDestination current;

  /// Increments on each explicit tab selection, including a re-tap.
  final int retapEpoch;

  /// Which tab was re-tapped (valid with the latest [retapEpoch]).
  final AppDestination? retapDestination;

  bool isActive(AppDestination d) => current == d;

  static ShellTabScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellTabScope>();
  }

  static ShellTabScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'ShellTabScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(ShellTabScope oldWidget) {
    return current != oldWidget.current ||
        retapEpoch != oldWidget.retapEpoch ||
        retapDestination != oldWidget.retapDestination;
  }
}

/// Wire a tab root page to [ShellTabScope]: hide → ephemeral clear; re-tap → scroll.
mixin ShellTabAware<T extends StatefulWidget> on State<T> {
  AppDestination get shellTab;

  ScrollController? get shellScrollController => null;

  bool? _wasActive;
  int _seenRetapEpoch = 0;
  bool _retapSynced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = ShellTabScope.maybeOf(context);
    if (scope == null) return;

    final active = scope.isActive(shellTab);
    if (_wasActive != true && active) {
      onShellTabVisible();
    }
    if (_wasActive == true && !active) {
      onShellTabHidden();
    }
    _wasActive = active;

    if (!_retapSynced) {
      _seenRetapEpoch = scope.retapEpoch;
      _retapSynced = true;
      return;
    }
    if (scope.retapEpoch != _seenRetapEpoch &&
        scope.retapDestination == shellTab) {
      _seenRetapEpoch = scope.retapEpoch;
      onShellTabRetap();
    }
  }

  /// Tab became visible (including first mount under IndexedStack).
  void onShellTabVisible() {
    _jumpToTop();
  }

  /// Tab became inactive — close menus / unfocus; keep durable state.
  void onShellTabHidden() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Same tab tapped again — after nested nav pop-to-root (shell), scroll up.
  void onShellTabRetap() {
    FocusManager.instance.primaryFocus?.unfocus();
    _jumpToTop();
  }

  void _jumpToTop() {
    final c = shellScrollController;
    if (c != null && c.hasClients) {
      // The retained scroll position must be reset before this frame paints.
      c.jumpTo(0);
    }
  }
}
