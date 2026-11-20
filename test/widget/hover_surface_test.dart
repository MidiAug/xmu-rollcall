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
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/features/homework/homework_list_row.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';

void main() {
  setUpAll(() async {
    if (Platform.environment['CAPTURE_DESKTOP_UI'] == '1') {
      await loadDesktopPreviewFonts();
    }
  });
  for (final dark in [false, true]) {
    for (final kind in ['settings', 'homework']) {
      for (final reducedMotion in [false, true]) {
        testWidgets(
          '$kind navigation indicator responds without filling row dark=$dark reduced=$reducedMotion',
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
                                    child: kind == 'homework'
                                        ? HomeworkListRow(
                                            key: row,
                                            item: const HomeworkItem(
                                              id: 1,
                                              title: '课程作业',
                                              courseId: 2,
                                            ),
                                            subtitle: '课程名称',
                                            trailing: const Text('11/25 23:59'),
                                            onTap: () => calls++,
                                          )
                                        : SettingsRow(
                                            key: row,
                                            leading: const Icon(
                                              AppIcons.location,
                                            ),
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
            Color? arrowColor() => kind == 'settings'
                ? tester.widget<Icon>(find.byKey(arrow)).color
                : IconTheme.of(
                    tester.element(find.byIcon(AppIcons.right)),
                  ).color;
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
                    '${directory.path}/$kind-$label-$dark-$reducedMotion.png',
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
            // Window-switch shortcuts are not keyboard navigation within the app.
            await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
            await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
            await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
            await tester.pumpAndSettle();
            expect(arrowColor(), palette.muted);
            expect(await backgroundPixel('app-return'), idlePixel);
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
    }
    testWidgets(
      'mouse navigation and app return stay quiet then Tab restores focus dark=$dark',
      (tester) async {
        final previous = FocusNode();
        addTearDown(previous.dispose);
        final capture = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: SizedBox(
                    width: 360,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          focusNode: previous,
                          onPressed: () {},
                          child: const Text('前一个操作'),
                        ),
                        RepaintBoundary(
                          key: capture,
                          child: SettingsSection(
                            padTop: false,
                            children: [
                              SettingsRow(
                                title: '协助同学',
                                trailing: const Icon(AppIcons.right),
                                onTap: () => AppPageRoutes.push(
                                  context,
                                  const SubpageScaffold(
                                    title: '协助同学',
                                    body: SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('协助同学'));
        await tester.pumpAndSettle();
        expect(find.byType(SubpageScaffold), findsOneWidget);
        await tester.tap(find.byTooltip('返回').first);
        await tester.pumpAndSettle();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        final p = AppPalette.of(tester.element(find.byType(SettingsRow)));
        expect(tester.widget<Icon>(find.byIcon(AppIcons.right)).color, p.muted);
        previous.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          tester.widget<Icon>(find.byIcon(AppIcons.right)).color,
          p.primary,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(SubpageScaffold), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
    testWidgets(
      'settings group paints all four focus edges inside first middle and last rows dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(600, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        final beforeFocus = FocusNode();
        addTearDown(beforeFocus.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        focusNode: beforeFocus,
                        onPressed: () {},
                        child: const Text('前一个操作'),
                      ),
                      RepaintBoundary(
                        key: capture,
                        child: SettingsSection(
                          padTop: false,
                          children: [
                            for (var i = 0; i < 3; i++)
                              SettingsRow(
                                key: ValueKey('focus-row-$i'),
                                title: '跳转入口 $i',
                                trailing: const Icon(AppIcons.right),
                                onTap: () {},
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        beforeFocus.requestFocus();
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          final row = find.byKey(ValueKey('focus-row-$i'));
          expect(
            tester
                .widget<FocusableActionDetector>(
                  find.descendant(
                    of: row,
                    matching: find.byType(FocusableActionDetector),
                  ),
                )
                .focusNode!
                .hasFocus,
            isTrue,
          );
          final rect = tester.getRect(row);
          final render =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final offset = render.globalToLocal(rect.topLeft);
          final color = AppPalette.of(tester.element(row)).focus;
          await tester.runAsync(() async {
            final image = await render.toImage();
            try {
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
              for (final point in [
                Offset(4, rect.height / 2),
                Offset(rect.width - 5, rect.height / 2),
                Offset(rect.width / 2, 4),
                Offset(rect.width / 2, rect.height - 5),
              ]) {
                final spot = offset + point;
                final at =
                    (spot.dy.floor() * image.width + spot.dx.floor()) * 4;
                expect(
                  Color.fromARGB(
                    bytes[at + 3],
                    bytes[at],
                    bytes[at + 1],
                    bytes[at + 2],
                  ),
                  color,
                  reason: 'row $i focus edge $point',
                );
              }
              if (Platform.environment['CAPTURE_DESKTOP_UI'] == '1') {
                final png = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory('build/interaction-ui').create(recursive: true);
                await File(
                  'build/interaction-ui/group-focus-$i-$dark.png',
                ).writeAsBytes(png!.buffer.asUint8List());
              }
            } finally {
              image.dispose();
            }
          });
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
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
