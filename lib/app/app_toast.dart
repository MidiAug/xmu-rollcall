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
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    bool error = false,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismiss();

    final p = AppPalette.of(context);
    final size = MediaQuery.sizeOf(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final wide = size.width >= AppLayout.shellBreakpoint;
    // ~32% from bottom on phone; desktop a bit higher.
    final bottom = wide
        ? (size.height * 0.22).clamp(72.0, 160.0)
        : (size.height * 0.18).clamp(88.0, 140.0) + bottomSafe * 0.25;

    _entry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          left: 0,
          right: 0,
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
