import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  for (final extent in [34.0, 40.0, 44.0]) {
    testWidgets('refresh rotation keeps its pivot centered at $extent', (
      tester,
    ) async {
      final done = Completer<void>();
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: desktopCaptureTheme(AppTheme.light()),
          home: RepaintBoundary(
            key: const ValueKey('desktop-ui-capture'),
            child: Scaffold(
              body: Center(
                child: AppRefreshButton(
                  extent: extent,
                  onRefresh: () {
                    requests++;
                    return done.future;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final button = find.byType(AppRefreshButton);
      final bounds = tester.getRect(button);
      await tester.tap(button);
      await tester.pump();
      for (var frame = 0; frame < 8; frame++) {
        final spin = find.descendant(
          of: button,
          matching: find.byType(RotationTransition),
        );
        final icon = find.descendant(of: spin, matching: find.byType(Icon));
        final size = tester.getSize(spin);
        expect(
          size.width,
          size.height,
          reason: 'rotation must use a square icon box',
        );
        expect(tester.getCenter(spin).dx, closeTo(bounds.center.dx, .01));
        expect(tester.getCenter(spin).dy, closeTo(bounds.center.dy, .01));
        expect(tester.getCenter(icon).dx, closeTo(bounds.center.dx, .01));
        expect(tester.getCenter(icon).dy, closeTo(bounds.center.dy, .01));
        final offset = await tester.runAsync(() async {
          final image =
              await (tester
                          .element(
                            find.byKey(const ValueKey('desktop-ui-capture')),
                          )
                          .findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final bytes = data!.buffer.asUint8List();
          var mass = 0.0, xMass = 0.0, yMass = 0.0;
          // Measure actual ink, not just the transform box: an asymmetric
          // glyph can orbit despite perfectly centered widget bounds.
          for (
            var y = bounds.center.dy.floor() - 12;
            y <= bounds.center.dy.floor() + 12;
            y++
          ) {
            for (
              var x = bounds.center.dx.floor() - 12;
              x <= bounds.center.dx.floor() + 12;
              x++
            ) {
              final at = (y * image.width + x) * 4;
              final sum = bytes[at] + bytes[at + 1] + bytes[at + 2];
              if (sum >= 540) continue;
              final weight = 1 - sum / 765;
              mass += weight;
              xMass += (x + .5) * weight;
              yMass += (y + .5) * weight;
            }
          }
          image.dispose();
          return Offset(xMass / mass, yMass / mass) - bounds.center;
        });
        expect(
          offset!.distance,
          lessThan(1),
          reason: 'visible ink must rotate in place',
        );
        await captureDesktopUi(tester, 'refresh-$extent-frame-$frame');
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(button);
      expect(requests, 1);
      done.complete();
      await tester.pumpAndSettle();
      expect(tester.getRect(button), bounds);
      expect(
        tester
            .widget<RotationTransition>(
              find.descendant(
                of: button,
                matching: find.byType(RotationTransition),
              ),
            )
            .turns
            .value,
        0,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
