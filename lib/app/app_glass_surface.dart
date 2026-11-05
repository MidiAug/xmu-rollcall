import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Frosted chrome is clipped to its own bounds. Static content surfaces use
/// blur=0 so scrolling data never pays for a backdrop filter per row.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.blur = 18,
    this.opacity = .78,
  });
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final double blur, opacity;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.island);
    final highContrast = MediaQuery.highContrastOf(context);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            p.surface.withValues(alpha: highContrast || opacity == 1 ? 1 : .97),
            p.surface.withValues(alpha: highContrast ? 1 : opacity),
          ],
        ),
        border: Border.all(
          color: p.isDark
              ? Colors.white.withValues(alpha: .12)
              : p.border.withValues(alpha: .8),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? .18 : .035),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? .08 : .015),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: blur > 0 && !highContrast
            ? BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: surface,
              )
            : surface,
      ),
    );
  }
}
