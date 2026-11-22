import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// A single symbol family at a common optical size, separate from its hit area.
class AppServiceSymbol extends StatelessWidget {
  const AppServiceSymbol({super.key, required this.icon, this.size = 40});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final highContrast = MediaQuery.highContrastOf(context);
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
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
        child: Icon(icon, size: size * .6, color: p.primary),
      ),
    );
  }
}
