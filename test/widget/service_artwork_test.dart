import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_service_symbol.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

void main() {
  const icons = [
    AppIcons.serviceMap,
    AppIcons.serviceExams,
    AppIcons.serviceGpa,
    AppIcons.serviceCalendar,
    AppIcons.serviceGrading,
  ];
  for (final dark in [false, true]) {
    for (final icon in icons) {
      testWidgets(
        'service artwork is visible at actual size $icon dark=$dark',
        (tester) async {
          const key = ValueKey('artwork-pixels');
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: key,
                    child: AppServiceSymbol(icon: icon, size: 44),
                  ),
                ),
              ),
            ),
          );
          // Decode the real production provider, including its resize key. A
          // settled widget tree alone does not mean an async bitmap is ready.
          final image = find.descendant(
            of: find.byKey(key),
            matching: find.byType(Image),
          );
          expect(image, findsOneWidget);
          await tester.runAsync(
            () => precacheImage(
              tester.widget<Image>(image).image,
              tester.element(image),
            ),
          );
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(key),
          );
          final bounds = await tester.runAsync(() async {
            final pixels = await boundary.toImage(pixelRatio: 2);
            try {
              final bytes = (await pixels.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
              var left = pixels.width,
                  right = -1,
                  top = pixels.height,
                  bottom = -1;
              for (var y = 0; y < pixels.height; y++) {
                for (var x = 0; x < pixels.width; x++) {
                  final i = (y * pixels.width + x) * 4;
                  if (bytes[i + 3] > 40 && bytes[i + 2] - bytes[i] > 12) {
                    if (x < left) left = x;
                    if (x > right) right = x;
                    if (y < top) top = y;
                    if (y > bottom) bottom = y;
                  }
                }
              }
              return Rect.fromLTRB(
                left / 2,
                top / 2,
                (right + 1) / 2,
                (bottom + 1) / 2,
              );
            } finally {
              pixels.dispose();
            }
          });
          expect(bounds!.longestSide, greaterThan(28));
          expect(bounds.shortestSide, greaterThan(14));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('high contrast uses a readable service symbol', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: const AppServiceSymbol(icon: AppIcons.serviceMap, size: 44),
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(AppIcons.serviceMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
