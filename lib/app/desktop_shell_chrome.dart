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
  final Map<AppDestination, ({Object owner, List<Widget> actions})>
  _rootActions = {};

  List<Widget> get activeRootActions =>
      _rootActions[_current]?.actions ?? const [];

  void setRootActions(AppDestination tab, Object owner, List<Widget> actions) {
    _rootActions[tab] = (owner: owner, actions: actions);
    _scheduleNotify();
  }

  void releaseRootActions(AppDestination tab, Object owner) {
    if (!identical(_rootActions[tab]?.owner, owner)) return;
    _rootActions.remove(tab);
    _scheduleNotify();
  }

  var _notifyScheduled = false;
  var _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

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
    if (_notifyScheduled || _disposed) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (_disposed) return;
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

/// Root-page actions share the shell bar; nested page claims take precedence.
class DesktopRootActions extends StatefulWidget {
  const DesktopRootActions({
    super.key,
    required this.enabled,
    required this.actions,
    required this.child,
  });
  final bool enabled;
  final List<Widget> actions;
  final Widget child;
  @override
  State<DesktopRootActions> createState() => _DesktopRootActionsState();
}

class _DesktopRootActionsState extends State<DesktopRootActions> {
  DesktopShellChromeController? _chrome;
  AppDestination? _tab;
  final _owner = Object();

  void _sync() {
    _release();
    if (!widget.enabled || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _chrome = DesktopShellChromeScope.maybeOf(context, listen: false);
    _tab = ShellTabDestination.maybeOf(context);
    if (_tab != null) _chrome?.setRootActions(_tab!, _owner, widget.actions);
  }

  void _release() {
    if (_tab != null) _chrome?.releaseRootActions(_tab!, _owner);
    _chrome = null;
    _tab = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant DesktopRootActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled ||
        widget.actions != oldWidget.actions) {
      _sync();
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Provides [DesktopShellChromeController] to the shell tree.
class DesktopShellChromeScope
    extends InheritedNotifier<DesktopShellChromeController> {
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
