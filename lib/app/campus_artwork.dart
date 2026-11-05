import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Reduce luminance and saturation without inverting the original painting.
ColorFilter campusArtworkFilter(AppPalette palette) {
  if (!palette.isDark) {
    return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
  }
  const saturation = .5, brightness = .42;
  final r = (1 - saturation) * .2126,
      g = (1 - saturation) * .7152,
      b = (1 - saturation) * .0722;
  return ColorFilter.matrix([
    (r + saturation) * brightness,
    g * brightness,
    b * brightness,
    0,
    0,
    r * brightness,
    (g + saturation) * brightness,
    b * brightness,
    0,
    0,
    r * brightness,
    g * brightness,
    (b + saturation) * brightness,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
}

class CampusArtworkTreatment extends StatelessWidget {
  const CampusArtworkTreatment({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final filtered = ColorFiltered(
      colorFilter: campusArtworkFilter(palette),
      child: child,
    );
    if (!palette.isDark) return filtered;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0, .2, .72, 1],
      ).createShader(bounds),
      child: filtered,
    );
  }
}
