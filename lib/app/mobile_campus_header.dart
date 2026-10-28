import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/campus_artwork.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Decorative masthead only. Text and controls remain native, accessible UI.
class MobileCampusHeader extends StatelessWidget {
  const MobileCampusHeader({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final android = Theme.of(context).platform == TargetPlatform.android;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final height =
        184.0 +
        (MediaQuery.sizeOf(context).width < 360 ? 40 : 0) +
        (scale - 1) * 72;
    return SizedBox(
      key: const ValueKey('mobile-campus-header'),
      height: height,
      child: Stack(
        children: [
          Positioned(
            // The painting has transparent sky; lift it without moving controls.
            top: android ? -60 : 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Opacity(
                  opacity: p.isDark ? .28 : .42,
                  child: CampusArtworkTreatment(
                    child: Image.asset(
                      key: const ValueKey('mobile-campus-artwork'),
                      'assets/illustrations/campus_header.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.bottomRight,
                      cacheWidth: 1200,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: android ? Alignment.topLeft : Alignment.centerLeft,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
