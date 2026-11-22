import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'app_glass_surface.dart';

/// A single group surface that keeps the enclosed list's lazy layout.
class AppSliverGroup extends StatelessWidget {
  const AppSliverGroup({super.key, required this.sliver});
  final Widget sliver;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.surfaceRim),
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppGlassSurface.groupShadows(p),
      ),
      sliver: SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        sliver: sliver,
      ),
    );
  }
}
