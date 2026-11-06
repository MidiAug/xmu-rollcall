import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  setUpAll(() async {
    if (Platform.environment['CAPTURE_DESKTOP_UI'] == '1') {
      await loadDesktopPreviewFonts();
    }
  });
  for (final dark in [false, true]) {
    for (final reducedMotion in [false, true]) {
      testWidgets(
        'settings navigation indicator responds without filling row dark=$dark reduced=$reducedMotion',
        (tester) async {
          final boundary = GlobalKey();
          final nextFocus = FocusNode();
          addTearDown(nextFocus.dispose);
          const row = ValueKey('navigation-row');
          const arrow = ValueKey('navigation-arrow');
          var calls = 0;
          late AppPalette palette;
          await tester.pumpWidget(
            MaterialApp(
              theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                platform: TargetPlatform.windows,
              ),
              home: Builder(
                builder: (context) {
                  palette = AppPalette.of(context);
                  return MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: reducedMotion),
                    child: Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RepaintBoundary(
                              key: boundary,
                              child: ColoredBox(
                                color: palette.surface,
                                child: SizedBox(
                                  width: 360,
                                  child: SettingsRow(
                                    key: row,
                                    leading: const Icon(AppIcons.location),
                                    title: '地点管理',
                                    trailing: const Icon(
                                      AppIcons.right,
                                      key: arrow,
                                      size: 18,
                                    ),
                                    onTap: () => calls++,
                                  ),
                                ),
                              ),
                            ),
                            TextButton(
                              focusNode: nextFocus,
                              onPressed: () {},
                              child: const Text('下一个操作'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          Color? arrowColor() => tester.widget<Icon>(find.byKey(arrow)).color;
          Future<int> backgroundPixel([
            String? label,
          ]) async => (await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            try {
              if (label != null &&
                  Platform.environment['CAPTURE_DESKTOP_UI'] == '1') {
                final png = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final directory = await Directory(
                  'build/interaction-ui',
                ).create(recursive: true);
                await File(
                  '${directory.path}/settings-$label-$dark-$reducedMotion.png',
                ).writeAsBytes(png!.buffer.asUint8List());
              }
              final data = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
              // Empty inner row space, away from the focus border/icons.
              final at = ((image.height ~/ 2) * image.width + 8) * 4;
              return (data[at + 3] << 24) |
                  (data[at] << 16) |
                  (data[at + 1] << 8) |
                  data[at + 2];
            } finally {
              image.dispose();
            }
          }))!;
          final before = tester.getRect(find.byKey(row));
          final idlePixel = await backgroundPixel('idle');
          expect(arrowColor(), palette.muted);
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          await mouse.moveTo(tester.getCenter(find.byKey(row)));
          await tester.pumpAndSettle();
          expect(arrowColor(), palette.ink);
          expect(await backgroundPixel('hover'), idlePixel);
          expect(
            RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
            SystemMouseCursors.basic,
          );
          await mouse.down(tester.getCenter(find.byKey(row)));
          await tester.pumpAndSettle();
          expect(arrowColor(), palette.primary);
          expect(await backgroundPixel('pressed'), idlePixel);
          await mouse.cancel();
          await tester.pumpAndSettle();
          expect(calls, 0);
          expect(arrowColor(), palette.ink);
          await mouse.moveTo(Offset.zero);
          await tester.pumpAndSettle();
          expect(arrowColor(), palette.muted);
          // Verify keyboard traversal from an actual neighbouring target,
          // independently of where the cancelled pointer left actual focus.
          nextFocus.requestFocus();
          await tester.pumpAndSettle();
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<FocusableActionDetector>(
                  find.descendant(
                    of: find.byKey(row),
                    matching: find.byType(FocusableActionDetector),
                  ),
                )
                .focusNode!
                .hasFocus,
            isTrue,
          );
          expect(arrowColor(), palette.primary);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(calls, 1);
          expect(tester.getRect(find.byKey(row)), before);
          expect(await backgroundPixel('keyboard'), idlePixel);
          expect(tester.takeException(), isNull);
        },
        // ThemeData.platform only skins widgets. The real target also governs
        // keyboard events and FocusManager's desktop highlight policy.
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
    for (final kind in ['card', 'grouped', 'pill', 'strong-pill']) {
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
                    final Widget child = kind.endsWith('pill')
                        ? AppQuietPill(
                            onTap: () => taps++,
                            background: kind == 'strong-pill'
                                ? palette.primary
                                : null,
                            child: Center(
                              child: Text(
                                'Open',
                                style: TextStyle(
                                  color: kind == 'strong-pill'
                                      ? (dark ? palette.canvas : Colors.white)
                                      : palette.ink,
                                ),
                              ),
                            ),
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
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.basic,
        );
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
        final fill = kind == 'strong-pill'
            ? Color.lerp(palette.primary, palette.ink, .12)!
            : kind == 'pill'
            ? palette.controlHover
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
