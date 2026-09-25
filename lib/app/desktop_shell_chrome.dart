import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/destinations.dart';

/// One nested subpage's claim on the desktop title bar (Fluent single-chrome).
@immutable
class DesktopShellChromeClaim {
  const DesktopShellChromeClaim({
    required this.owner,
    required this.title,
    required this.onBack,
    this.actions,
  });

  final Object owner;
  final String title;
  final VoidCallback onBack;
  final List<Widget>? actions;
}

/// Per-tab claim stacks so [IndexedStack]-kept inactive tabs cannot steal chrome.
class DesktopShellChromeController extends ChangeNotifier {
  AppDestination _current = AppDestination.rollcall;
  final Map<AppDestination, List<DesktopShellChromeClaim>> _stacks = {
    for (final d in AppDestination.values) d: <DesktopShellChromeClaim>[],
  };
  var _notifyScheduled = false;

  AppDestination get current => _current;

  set current(AppDestination value) {
    if (_current == value) return;
    _current = value;
    _scheduleNotify();
  }

  DesktopShellChromeClaim? get activeClaim {
    final stack = _stacks[_current]!;
    if (stack.isEmpty) return null;
    return stack.last;
  }

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  void claim({
    required AppDestination tab,
    required Object owner,
    required String title,
    required VoidCallback onBack,
    List<Widget>? actions,
  }) {
    final stack = _stacks[tab]!;
    final next = DesktopShellChromeClaim(
      owner: owner,
      title: title,
      onBack: onBack,
      actions: actions,
    );
    final i = stack.indexWhere((c) => identical(c.owner, owner));
    if (i >= 0) {
      stack[i] = next;
      // Keep owner at top if it re-claims after a deeper page pops under it —
      // normal path: owner is already last while mounted.
      if (i != stack.length - 1) {
        stack
          ..removeAt(i)
          ..add(next);
      }
    } else {
      stack.add(next);
    }
    _scheduleNotify();
  }

  void release({required AppDestination tab, required Object owner}) {
    final stack = _stacks[tab]!;
    final before = stack.length;
    stack.removeWhere((c) => identical(c.owner, owner));
    if (stack.length != before) _scheduleNotify();
  }
}

/// Provides [DesktopShellChromeController] to the shell tree.
class DesktopShellChromeScope extends InheritedNotifier<DesktopShellChromeController> {
  const DesktopShellChromeScope({
    super.key,
    required DesktopShellChromeController controller,
    required super.child,
  }) : super(notifier: controller);

  static DesktopShellChromeController? maybeOf(
    BuildContext context, {
    bool listen = true,
  }) {
    if (listen) {
      return context
          .dependOnInheritedWidgetOfExactType<DesktopShellChromeScope>()
          ?.notifier;
    }
    return context
        .getInheritedWidgetOfExactType<DesktopShellChromeScope>()
        ?.notifier;
  }

  static DesktopShellChromeController of(
    BuildContext context, {
    bool listen = true,
  }) {
    final c = maybeOf(context, listen: listen);
    assert(c != null, 'DesktopShellChromeScope not found');
    return c!;
  }
}

/// Marks which shell tab a nested [Navigator] belongs to (for chrome claims).
class ShellTabDestination extends InheritedWidget {
  const ShellTabDestination({
    super.key,
    required this.destination,
    required super.child,
  });

  final AppDestination destination;

  static AppDestination? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ShellTabDestination>()
        ?.destination;
  }

  @override
  bool updateShouldNotify(ShellTabDestination oldWidget) {
    return destination != oldWidget.destination;
  }
}
