import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Unified short feedback via root Overlay.
///
/// Mobile: mid-lower rounded capsule (mainstream). Desktop: same band, slightly
/// higher so it clears window chrome. Prefer this over [SnackBar].
///
/// See docs/research/19-keyboard-dialog-and-toast.md.
abstract final class AppToast {
  static _AppToastRegionState? _region;
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    bool error = false,
    Duration duration = const Duration(milliseconds: 2200),
    OverlayState? targetOverlay,
  }) {
    final overlay =
        targetOverlay ??
        Overlay.maybeOf(context, rootOverlay: true) ??
        Navigator.maybeOf(context)?.overlay;
    if (overlay == null) return;

    dismiss();

    final p = AppPalette.of(context);
    final size = MediaQuery.sizeOf(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final wide = size.width >= AppLayout.shellBreakpoint;
    final region = _region?.boundsIn(overlay);
    final rightInset = region == null
        ? 0.0
        : (overlay.context.findRenderObject()! as RenderBox).size.width -
              region.right;
    // ~32% from bottom on phone; desktop a bit higher.
    final bottom = wide
        ? (size.height * 0.22).clamp(72.0, 160.0)
        : (size.height * 0.18).clamp(88.0, 140.0) + bottomSafe * 0.25;

    final viewKey = GlobalKey<_AppToastViewState>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          left: region?.left ?? 0,
          right: rightInset,
          bottom: bottom,
          child: IgnorePointer(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: wide ? 360 : size.width * 0.72,
                ),
                child: _AppToastView(
                  key: viewKey,
                  message: message,
                  error: error,
                  isDark: p.isDark,
                  danger: p.danger,
                ),
              ),
            ),
          ),
        );
      },
    );

    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(duration, () => _fadeOut(entry, viewKey));
  }

  static void _fadeOut(
    OverlayEntry entry,
    GlobalKey<_AppToastViewState> viewKey,
  ) {
    if (!identical(_entry, entry)) return;
    final view = viewKey.currentState;
    if (view == null || !view.mounted) {
      dismiss();
      return;
    }
    view.dismissAnimated().then((_) {
      if (!identical(_entry, entry)) return;
      _timer?.cancel();
      _timer = null;
      _entry?.remove();
      _entry = null;
    });
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _AppToastView extends StatefulWidget {
  const _AppToastView({
    super.key,
    required this.message,
    required this.error,
    required this.isDark,
    required this.danger,
  });

  final String message;
  final bool error;
  final bool isDark;
  final Color danger;

  @override
  State<_AppToastView> createState() => _AppToastViewState();
}

class _AppToastViewState extends State<_AppToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 120),
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeIn,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: .97,
    end: 1,
  ).animate(_opacity);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, .14),
    end: Offset.zero,
  ).animate(_opacity);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  Future<void> dismissAnimated() async {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0;
      return;
    }
    await _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.error
        ? widget.danger.withValues(alpha: 0.94)
        : widget.isDark
        ? const Color(0xF2323744)
        : const Color(0xEB1E222B);
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: widget.error ? .18 : .12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: widget.isDark ? .36 : .18,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: widget.isDark ? .18 : .06,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                    decoration: TextDecoration.none,
                    color: widget.error
                        ? Colors.white
                        : const Color(0xFFF4F4F5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The shell registers its actual content bounds, excluding navigation chrome.
class AppToastRegion extends StatefulWidget {
  const AppToastRegion({super.key, required this.child});
  final Widget child;

  @override
  State<AppToastRegion> createState() => _AppToastRegionState();
}

class _AppToastRegionState extends State<AppToastRegion> {
  final _boundsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    AppToast._region = this;
  }

  Rect? boundsIn(OverlayState overlay) {
    final box = _boundsKey.currentContext?.findRenderObject();
    final target = overlay.context.findRenderObject();
    if (box is! RenderBox || target is! RenderBox || !box.hasSize) return null;
    return target.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
  }

  @override
  void dispose() {
    if (identical(AppToast._region, this)) AppToast._region = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox.expand(key: _boundsKey, child: widget.child);
}
