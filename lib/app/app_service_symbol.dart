import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Destination symbols share the same optical family as the app's controls.
/// Their accent identifies the service without adding another raised surface.
class AppServiceSymbol extends StatelessWidget {
  const AppServiceSymbol({super.key, required this.icon, this.size = 36});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: Icon(icon, size: size * .9, color: AppPalette.of(context).primary),
    ),
  );
}
