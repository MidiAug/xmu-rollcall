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
  setUpAll(loadDesktopPreviewFonts);
  testWidgets('segment selection slides with an opaque mint surface', (
    tester,
  ) async {
    var selected = 0;
    final capture = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: capture,
              child: StatefulBuilder(
                builder: (context, set) => AppSegmentedControl<int>(
                  segments: const [
                    AppSegment(value: 0, label: '全部 1'),
                    AppSegment(value: 1, label: '进行中 0'),
                    AppSegment(value: 2, label: '已截止 1'),
                  ],
                  value: selected,
                  onChanged: (v) => set(() => selected = v),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final marker = find.descendant(
      of: find.byKey(const ValueKey('segment-selection')),
      matching: find.byType(FractionallySizedBox),
    );
    final start = tester.getRect(marker).left;
    await tester.tap(find.text('已截止 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 35));
    final middle = tester.getRect(marker).left;
    final fill = tester.widget<DecoratedBox>(
      find.descendant(of: marker, matching: find.byType(DecoratedBox)),
    );
    final color = (fill.decoration as BoxDecoration).color!;
    expect(color.a, 1);
    expect(color.computeLuminance(), greaterThan(.7));
    expect(middle, greaterThan(start));
    await _capture(tester, capture, 'segments-mid-slide');
    await tester.pumpAndSettle();
    expect(tester.getRect(marker).left, greaterThan(middle));
    expect(selected, 2);
    Focus.of(tester.element(find.text('已截止 1'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(selected, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'action menu uses the shared end-aligned anchor, keyboard and close registry',
    (tester) async {
      var calls = 0;
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) =>
              RepaintBoundary(key: capture, child: child!),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  top: 30,
                  right: 24,
                  child: AppActionMenu<int>(
                    tooltip: '签到操作',
                    actions: const [
                      AppMenuAction(1, '自动检测设置', icon: AppIcons.settings),
                      AppMenuAction(2, '签到记录', icon: AppIcons.history),
                    ],
                    onSelected: (_) => calls++,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final trigger = tester.getRect(find.byTooltip('签到操作'));
      await tester.tap(find.byTooltip('签到操作'));
      await tester.pumpAndSettle();
      final option = find.widgetWithText(AppMenuOption, '自动检测设置');
      final surface = find
          .ancestor(
            of: option,
            matching: find.byWidgetPredicate(
              (w) => w is Material && w.shape is RoundedRectangleBorder,
            ),
          )
          .first;
      final menu = tester.getRect(surface);
      expect(menu.right, closeTo(trigger.right, 1));
      expect(menu.top, closeTo(trigger.bottom + AppSpace.xs, 1));
      await _capture(tester, capture, 'action-menu');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AppMenuOption), findsNothing);
      await tester.tap(find.byTooltip('签到操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('签到记录'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(AppMenuOption), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (Platform.environment['CAPTURE_DESKTOP_WORKSPACE'] != '1') return;
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('.tools/polish-interactions').createSync(recursive: true);
    File(
      '.tools/polish-interactions/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
