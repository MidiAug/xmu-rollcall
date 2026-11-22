import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// A single symbol family at a common optical size, separate from its hit area.
class AppServiceSymbol extends StatelessWidget {
  const AppServiceSymbol({
    super.key,
    this.icon,
    this.child,
    this.size = 40,
    this.iconSize,
  }) : assert(icon != null || child != null);

  final IconData? icon;
  final Widget? child;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final effectiveIconSize = iconSize ?? (size <= 32 ? 16.0 : size * .6);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: highContrast ? p.surface : null,
          gradient: highContrast
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: p.iconWellColors,
                ),
          border: Border.all(color: highContrast ? p.primary : p.iconWellRim),
          borderRadius: BorderRadius.circular(
            size <= 32 ? 9.0 : AppRadii.input,
          ),
        ),
        child: child != null
            ? IconTheme.merge(
                data: IconThemeData(color: p.primary, size: effectiveIconSize),
                child: Center(child: child!),
              )
            : Icon(icon, size: effectiveIconSize, color: p.primary),
      ),
    );
  }
}
