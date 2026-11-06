import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Subpages retain a short directional cue without moving the desktop workspace.
abstract final class AppPageRoutes {
  static const _slideFraction = 0.08;

  static Future<T?> push<T extends Object?>(BuildContext context, Widget page) {
    AppShellSelect.closeAll();
    return Navigator.of(context).push<T>(
      build<T>(page, reduceMotion: MediaQuery.disableAnimationsOf(context)),
    );
  }

  static Route<T> build<T extends Object?>(
    Widget page, {
    bool reduceMotion = false,
  }) {
    return PageRouteBuilder<T>(
      transitionDuration: reduceMotion ? Duration.zero : AppMotion.page,
      reverseTransitionDuration: reduceMotion ? Duration.zero : AppMotion.page,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          _SubpageTransition(
            animation: animation,
            reduceMotion: reduceMotion,
            child: child,
          ),
    );
  }
}

class _SubpageTransition extends StatefulWidget {
  const _SubpageTransition({
    required this.animation,
    required this.reduceMotion,
    required this.child,
  });
  final Animation<double> animation;
  final bool reduceMotion;
  final Widget child;

  @override
  State<_SubpageTransition> createState() => _SubpageTransitionState();
}

class _SubpageTransitionState extends State<_SubpageTransition> {
  // Retain the curve's direction when a user reverses before arrival; switching
  // to a fresh reverse curve mid-flight would jump to another visual position.
  late CurvedAnimation _curved;

  void _bindAnimation() {
    _curved = CurvedAnimation(
      parent: widget.animation,
      curve: AppMotion.pageCurve,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void initState() {
    super.initState();
    _bindAnimation();
  }

  @override
  void didUpdateWidget(covariant _SubpageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animation != oldWidget.animation) {
      _curved.dispose();
      _bindAnimation();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    final direction = Directionality.of(context);
    if (AppMobileUi.useTouchChrome(context)) {
      return FadeTransition(
        opacity: _curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(AppPageRoutes._slideFraction, 0),
            end: Offset.zero,
          ).animate(_curved),
          textDirection: direction,
          child: widget.child,
        ),
      );
    }
    // Keep dense text opaque: fading an entire page over the previous list
    // combines two sets of labels. A stationary surface also covers the narrow
    // edge exposed by the directional cue during navigation.
    return ClipRect(
      child: ColoredBox(
        color: AppPalette.of(context).canvas,
        child: AnimatedBuilder(
          animation: _curved,
          child: widget.child,
          // A wide window must not turn a small navigation cue into
          // a long horizontal sweep across a dense list or form.
          builder: (context, child) => Transform.translate(
            offset: Offset(
              (direction == TextDirection.rtl ? -16 : 16) * (1 - _curved.value),
              0,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
