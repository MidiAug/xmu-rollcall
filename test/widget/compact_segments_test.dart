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

const _choices = [
  AppSegment(value: 0, label: '浅色'),
  AppSegment(value: 1, label: '暗色'),
  AppSegment(value: 2, label: '跟随系统'),
];

void main() {
  setUpAll(loadDesktopPreviewFonts);
  for (final dark in [false, true]) {
    for (final highContrast in [false, true]) {
      testWidgets(
        'compact embedded choices preserve pointer keyboard and visible states dark=$dark contrast=$highContrast',
        (tester) async {
          final capture = GlobalKey();
          var selected = 0;
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
                    data: MediaQuery.of(context).copyWith(
                      highContrast: highContrast,
                      disableAnimations: true,
                    ),
                    child: Scaffold(
                      body: Center(
                        child: RepaintBoundary(
                          key: capture,
                          child: StatefulBuilder(
                            builder: (context, set) => AppSegmentedControl<int>(
                              compact: true,
                              segments: _choices,
                              value: selected,
                              onChanged: (value) => set(() => selected = value),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          final control = find.byType(AppSegmentedControl<int>);
          final first = find.byKey(const ValueKey(0));
          final last = find.byKey(const ValueKey(2));
          final before = tester.getRect(control);
          expect(before.height, 32);
          Future<int> sample() async => (await tester.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            try {
              final data = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
              final offset = tester.getTopLeft(first) - before.topLeft;
              final at =
                  ((offset.dy + 16).floor() * image.width +
                      (offset.dx + 6).floor()) *
                  4;
              return (data[at + 3] << 24) |
                  (data[at] << 16) |
                  (data[at + 1] << 8) |
                  data[at + 2];
            } finally {
              image.dispose();
            }
          }))!;
          final idle = await sample();
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          await mouse.moveTo(tester.getCenter(first));
          await tester.pumpAndSettle();
          expect(await sample(), isNot(idle));
          expect(
            tester.widget<Text>(find.text('浅色')).style!.color,
            palette.primary,
          );
          expect(
            RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
            SystemMouseCursors.basic,
          );
          await mouse.down(tester.getCenter(first));
          await tester.pumpAndSettle();
          expect(tester.getRect(control), before);
          await mouse.up();
          await mouse.moveTo(Offset.zero);
          await tester.pumpAndSettle();
          expect(await sample(), idle);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          expect(selected, 1);
          await tester.sendKeyEvent(LogicalKeyboardKey.end);
          await tester.pumpAndSettle();
          expect(selected, 2);
          final selection = find.descendant(
            of: find.byKey(const ValueKey('segment-selection')),
            matching: find.byType(FractionallySizedBox),
          );
          expect(
            tester.getRect(selection).left,
            closeTo(tester.getRect(last).left, .01),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.home);
          await tester.pumpAndSettle();
          expect(selected, 0);
          expect(tester.getRect(control), before);
          if (Platform.environment['CAPTURE_COMPACT_SEGMENTS_UI'] == '1') {
            await tester.runAsync(() async {
              final image =
                  await (capture.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              try {
                final bytes = (await image.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!;
                final file = File(
                  'build/settings-compact-review/segments-$dark-$highContrast.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
  for (final touch in [false, true]) {
    for (final scale in [1.0, 2.5]) {
      testWidgets('compact choices grow for text touch=$touch scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(touch ? 390 : 800, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light().copyWith(
              platform: touch ? TargetPlatform.android : TargetPlatform.windows,
            ),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Center(
                    child: AppSegmentedControl<int>(
                      compact: true,
                      expanded: touch,
                      segments: _choices,
                      value: 0,
                      onChanged: _ignore,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final control = find.byType(AppSegmentedControl<int>);
        expect(AppMobileUi.useTouchChrome(tester.element(control)), touch);
        final height = tester.getSize(control).height;
        expect(height, greaterThanOrEqualTo(touch ? AppMobileUi.target : 32));
        if (scale > 1) {
          expect(height, greaterThan(touch ? AppMobileUi.target : 32));
        }
        for (final label in ['浅色', '暗色', '跟随系统']) {
          final text = find.text(label);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}

void _ignore(int _) {}
