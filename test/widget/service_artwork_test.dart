import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_service_symbol.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  setUpAll(loadDesktopPreviewFonts);
  const icons = [
    AppIcons.serviceMap,
    AppIcons.serviceExams,
    AppIcons.serviceGpa,
    AppIcons.serviceCalendar,
    AppIcons.serviceGrading,
  ];
  for (final dark in [false, true]) {
    for (final highContrast in [false, true]) {
      testWidgets(
        'service symbols have legible ink dark=$dark contrast=$highContrast',
        (tester) async {
          const key = ValueKey('symbol-pixels');
          final p = dark ? AppPalette.darkPalette : AppPalette.lightPalette;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: MediaQuery(
                data: MediaQueryData(highContrast: highContrast),
                child: Scaffold(
                  body: Center(
                    child: RepaintBoundary(
                      key: key,
                      child: ColoredBox(
                        color: p.surface,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final icon in icons)
                              AppServiceSymbol(icon: icon, size: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(Image), findsNothing);
          expect(find.byType(BackdropFilter), findsNothing);
          final counts = await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(key),
            );
            final image = await boundary.toImage(pixelRatio: 2);
            try {
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
              Color colorAt(int x, int y) {
                final i = (y * image.width + x) * 4;
                return Color.fromARGB(
                  bytes[i + 3],
                  bytes[i],
                  bytes[i + 1],
                  bytes[i + 2],
                );
              }

              return [
                for (var item = 0; item < icons.length; item++)
                  (() {
                    final background = colorAt(
                      item * 80 + 8,
                      40,
                    ).computeLuminance();
                    var ink = 0;
                    for (var y = 12; y < 68; y++) {
                      for (var x = item * 80 + 12; x < item * 80 + 68; x++) {
                        final foreground = colorAt(x, y).computeLuminance();
                        final ratio = foreground > background
                            ? (foreground + .05) / (background + .05)
                            : (background + .05) / (foreground + .05);
                        if (ratio >= 3) ink++;
                      }
                    }
                    return ink;
                  })(),
              ];
            } finally {
              image.dispose();
            }
          });
          for (var i = 0; i < icons.length; i++) {
            expect(
              counts![i],
              greaterThan(80),
              reason:
                  'A clear glyph needs real contrasting ink, not just a tinted backing.',
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
