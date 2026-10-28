import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmu_rollcall/app/chrome.dart';

/// Desktop back input follows route guards, including inner dialog steps.
/// The keyboard hook also works after mouse clicks clear the focused control.
class DesktopBackNavigation extends StatefulWidget {
  const DesktopBackNavigation({
    super.key,
    required this.navigatorKey,
    required this.child,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  State<DesktopBackNavigation> createState() => _DesktopBackNavigationState();
}

class _DesktopBackNavigationState extends State<DesktopBackNavigation> {
  bool _desktop = false;
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_key);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_key);
    super.dispose();
  }

  KeyEventResult _key(KeyEvent event) {
    if (!_desktop || event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) _back();
    return KeyEventResult.handled;
  }

  void _back() {
    if (AppShellSelect.dismissOpenMenu()) return;
    final navigator = widget.navigatorKey.currentState;
    if (navigator != null) unawaited(navigator.maybePop());
  }

  @override
  Widget build(BuildContext context) {
    _desktop = switch (Theme.of(context).platform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
    if (!_desktop) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse &&
            event.buttons & kBackMouseButton != 0) {
          _back();
        }
      },
      child: widget.child,
    );
  }
}
