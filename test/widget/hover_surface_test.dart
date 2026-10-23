import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

void main() {
  for (final dark in [false, true]) {
    for (final kind in ['card', 'grouped', 'pill']) {
      testWidgets('$kind hover fills its surface and stays clipped ($dark)', (
        tester,
      ) async {
        final boundary = GlobalKey();
        final control = GlobalKey();
        var taps = 0;
        late AppPalette palette;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) {
                    palette = AppPalette.of(context);
                    final Widget child = kind == 'pill'
                        ? AppQuietPill(
                            onTap: () => taps++,
                            child: const Center(child: Text('Open')),
                          )
                        : kind == 'grouped'
                        ? Panel(
                            padding: EdgeInsets.zero,
                            child: AppHoverSurface(
                              borderRadius: BorderRadius.zero,
                              outlined: false,
                              onTap: () => taps++,
                              child: const Center(child: Text('Open')),
                            ),
                          )
                        : AppHoverSurface(
                            onTap: () => taps++,
                            child: const Center(child: Text('Open')),
                          );
                    return RepaintBoundary(
                      key: boundary,
                      child: SizedBox(
                        width: 240,
                        height: 120,
                        child: ColoredBox(
                          color: palette.canvas,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: SizedBox.expand(key: control, child: child),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer();
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(find.byKey(control)));
        await tester.pumpAndSettle();
        final bytes = await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final rgba = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (Platform.environment['CAPTURE_HOVER_UI'] == '1') {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
              '.tools/hover-final/$kind-${dark ? 'dark' : 'light'}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(png!.buffer.asUint8List());
          }
          image.dispose();
          return rgba;
        });
        final rgba = bytes!.buffer.asUint8List();
        int pixel(int x, int y) {
          final i = (y * 240 + x) * 4;
          return (rgba[i + 3] << 24) |
              (rgba[i] << 16) |
              (rgba[i + 1] << 8) |
              rgba[i + 2];
        }

        // Corners and margins retain the page canvas. The right edge of an
        // inset/grouped row must have the same hover fill as its left edge.
        expect(pixel(20, 20), palette.canvas.toARGB32());
        expect(pixel(18, 60), palette.canvas.toARGB32());
        final fill = kind == 'pill'
            ? Color.alphaBlend(palette.hover, palette.surfaceHigh)
            : palette.cardHover;
        expect(pixel(23, 60), fill.toARGB32());
        expect(pixel(216, 60), fill.toARGB32());
        await tester.tap(find.byKey(control));
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
