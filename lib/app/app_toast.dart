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

    _entry = OverlayEntry(
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
                child: Material(
                  color: error
                      ? p.danger.withValues(alpha: 0.94)
                      : const Color(0xE61A1A1F),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                        color: error ? Colors.white : const Color(0xFFF4F4F5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);
    _timer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
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
