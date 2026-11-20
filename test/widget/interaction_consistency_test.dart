import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:xmu_rollcall/app/app_switch.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/rollcall/radar_place_card.dart';
import '../fixtures/preview_fonts.dart';

Future<Color> _pixel(
  WidgetTester tester,
  GlobalKey key,
  Offset position,
) async {
  return (await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    final index = (position.dy.floor() * image.width + position.dx.floor()) * 4;
    final color = Color.fromARGB(
      bytes[index + 3],
      bytes[index],
      bytes[index + 1],
      bytes[index + 2],
    );
    image.dispose();
    return color;
  }))!;
}

void main() {
  setUpAll(() async {
    if (Platform.environment['CAPTURE_INTERACTION_REVIEW'] == '1') {
      await loadDesktopPreviewFonts();
    }
  });
  for (final dark in [false, true]) {
    testWidgets('native controls keep arrow and text keeps I-beam dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: Column(
                children: [
                  AppSelectTrigger(label: '学期选择', onTap: () {}),
                  AppMenuOption(label: '课程选项', selected: false, onTap: () {}),
                  AppCheckbox(value: false, label: '选择学生', onChanged: (_) {}),
                  AppSwitch(value: false, onChanged: (_) {}),
                  const TextField(),
                ],
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(700, 500));
      addTearDown(mouse.removePointer);
      for (final type in [
        AppSelectTrigger,
        AppMenuOption,
        AppCheckbox,
        AppSwitch,
      ]) {
        await mouse.moveTo(tester.getCenter(find.byType(type)));
        await tester.pump();
        expect(
          RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
          SystemMouseCursors.basic,
          reason: '$type',
        );
      }
      await mouse.moveTo(tester.getCenter(find.byType(TextField)));
      await tester.pump();
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.text,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    for (final kind in ['select', 'segment', 'menu']) {
      final segment = kind == 'segment';
      testWidgets(
        'pointer focus leaves no keyboard border kind=$kind dark=$dark',
        (tester) async {
          final capture = GlobalKey();
          final control = GlobalKey();
          var calls = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: Scaffold(
                body: RepaintBoundary(
                  key: capture,
                  child: SizedBox(
                    width: 360,
                    child: segment
                        ? AppSegmentedControl<int>(
                            key: control,
                            value: 0,
                            segments: const [
                              AppSegment(value: 0, label: '本周'),
                              AppSegment(value: 1, label: '整学期'),
                            ],
                            onChanged: (_) => calls++,
                          )
                        : kind == 'menu'
                        ? AppMenuOption(
                            key: control,
                            label: '当前课程',
                            selected: true,
                            onTap: () => calls++,
                          )
                        : AppSelectTrigger(
                            key: control,
                            label: '选择学期',
                            onTap: () => calls++,
                          ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final surface = find
              .descendant(
                of: find.byKey(control),
                matching: find.byType(AnimatedContainer),
              )
              .first;
          final rect = tester.getRect(surface);
          final point =
              rect.centerLeft -
              tester.getTopLeft(find.byKey(capture)) +
              Offset(segment ? 2.5 : .5, 0);
          final idle = await _pixel(tester, capture, point);
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: const Offset(700, 500));
          addTearDown(mouse.removePointer);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(await _pixel(tester, capture, point), isNot(idle));
          await mouse.down(rect.center);
          await mouse.up();
          await mouse.moveTo(const Offset(700, 500));
          await tester.pumpAndSettle();
          expect(await _pixel(tester, capture, point), idle);
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          expect(await _pixel(tester, capture, point), isNot(idle));
          // Capture the actual keyboard state separately from pointer interaction.
          if (Platform.environment['CAPTURE_INTERACTION_REVIEW'] == '1') {
            await tester.runAsync(() async {
              final image =
                  await (capture.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/interaction-review/keyboard-$kind-$dark.png',
              );
              file.parent.createSync(recursive: true);
              file.writeAsBytesSync(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.sendKeyEvent(
            segment ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.enter,
          );
          await tester.pumpAndSettle();
          expect(calls, greaterThan(0));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }

    testWidgets('radar location actions support keyboard choice dark=$dark', (
      tester,
    ) async {
      RadarLocationAction? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showRadarLocationSheet(context);
                },
                child: const Text('打开地点'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开地点'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(result, RadarLocationAction.device);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
