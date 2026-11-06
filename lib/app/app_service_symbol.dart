import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Service illustrations match the selected board; ordinary controls continue
/// using AppIcons. Optical bounds remove only the assets' transparent margins.
class AppServiceSymbol extends StatelessWidget {
  const AppServiceSymbol({super.key, required this.icon, this.size = 36});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final artwork = switch (icon) {
      AppIcons.serviceMap => ('map', const Rect.fromLTRB(80, 350, 1175, 925)),
      AppIcons.serviceExams => (
        'exams',
        const Rect.fromLTRB(320, 185, 935, 1060),
      ),
      AppIcons.serviceGpa => ('gpa', const Rect.fromLTRB(180, 350, 1075, 975)),
      AppIcons.serviceCalendar => (
        'calendar',
        const Rect.fromLTRB(280, 260, 975, 1015),
      ),
      AppIcons.serviceGrading => (
        'grading',
        const Rect.fromLTRB(360, 325, 890, 960),
      ),
      _ => null,
    };
    Widget fallback() => Icon(icon, size: size * .9, color: p.primary);
    Widget image = artwork == null || MediaQuery.highContrastOf(context)
        ? fallback()
        : FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              width: artwork.$2.width,
              height: artwork.$2.height,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: -artwork.$2.left,
                    top: -artwork.$2.top,
                    width: 1254,
                    height: 1254,
                    child: Image.asset(
                      'assets/illustrations/service_${artwork.$1}.png',
                      width: 1254,
                      height: 1254,
                      // Decode stays small; retain the source coordinate system
                      // when fitting the optical frame below.
                      fit: BoxFit.fill,
                      cacheWidth:
                          (size *
                                  MediaQuery.devicePixelRatioOf(context) *
                                  1254 /
                                  artwork.$2.longestSide *
                                  1.4)
                              .ceil()
                              .clamp(96, 384),
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, _, _) => Padding(
                        padding: EdgeInsets.fromLTRB(
                          artwork.$2.left,
                          artwork.$2.top,
                          1254 - artwork.$2.right,
                          1254 - artwork.$2.bottom,
                        ),
                        child: FittedBox(child: fallback()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
    if (p.isDark && artwork != null && !MediaQuery.highContrastOf(context)) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          .65,
          0,
          0,
          0,
          70,
          0,
          .65,
          0,
          0,
          70,
          0,
          0,
          .65,
          0,
          70,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: image,
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(dimension: size, child: image),
    );
  }
}
