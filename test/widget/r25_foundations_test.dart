import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import '../fixtures/preview_fonts.dart';
import '../fixtures/desktop_ui_capture.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
}

void main() {
  initializeDesktopUiCapture();
  setUpAll(loadDesktopPreviewFonts);
  for (final dark in [false, true]) {
    final p = dark ? AppPalette.darkPalette : AppPalette.lightPalette;
    test('readable foundation pairs dark=$dark', () {
      for (final bg in [
        p.canvas,
        p.mobileCanvas,
        p.surface,
        p.popoverSurface,
        p.track,
        p.pillMuted,
        p.accentSoft,
        ...p.heroColors,
        ...p.iconWellColors,
      ]) {
        for (final fg in [p.ink, p.inkBody, p.muted]) {
          expect(
            contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: 'text $fg on $bg',
          );
        }
      }
      for (final pair in [
        (p.success, p.successSurface),
        (p.danger, p.dangerSoft),
        (p.primary, p.accentSoft),
        (p.ink, Color.alphaBlend(p.hoverOverlay, p.accentSoft)),
        (dark ? p.canvas : Colors.white, p.primary),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      // Accent icons/focus indicators carry meaning; subtle rims are decoration.
      for (final bg in [p.surface, p.canvas, ...p.iconWellColors]) {
        expect(contrast(p.primary, bg), greaterThanOrEqualTo(3));
      }
    });
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      for (final width in [320.0, 390.0]) {
        testWidgets(
          'floating nav and independent search $platform $width $dark',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final capture = GlobalKey();
            var current = AppDestination.rollcall;
            var searches = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: platform,
                ),
                home: StatefulBuilder(
                  builder: (context, setState) => RepaintBoundary(
                    key: capture,
                    child: Scaffold(
                      bottomNavigationBar: AppMobileNav(
                        current: current,
                        homeworkCount: 12,
                        onSearch: () => searches++,
                        onSelect: (next) => setState(() => current = next),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(AppGlassSurface), findsNWidgets(2));
            await tester.tap(find.text('工具'));
            await tester.pumpAndSettle();
            expect(current, AppDestination.campusTools);
            await tester.tap(
              find.byKey(const ValueKey('global-search-button')),
            );
            await tester.pumpAndSettle();
            expect(searches, 1);
            expect(find.text('12'), findsOneWidget);
            expect(tester.takeException(), isNull);
            if (Platform.environment['CAPTURE_DESKTOP_UI'] == '1') {
              await tester.runAsync(() async {
                final boundary =
                    capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage(pixelRatio: 2);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(
                  'build/r25-foundations',
                ).create(recursive: true);
                await File(
                  'build/r25-foundations/nav-${platform.name}-$width-$dark.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          },
        );
      }
    }
  }
}
