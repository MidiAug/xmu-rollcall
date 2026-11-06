import 'package:flutter/gestures.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  for (final width in [320.0, 960.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'shared select has bounded hover, keyboard and edge positioning at $width/$dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var value = 0;
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => RepaintBoundary(
                key: const ValueKey('desktop-ui-capture'),
                child: child!,
              ),
              theme: desktopCaptureTheme(
                dark ? AppTheme.dark() : AppTheme.light(),
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: StatefulBuilder(
                      builder: (context, setState) => AppShellSelect<int>(
                        key: const ValueKey('select'),
                        value: value,
                        items: const [0, 1, 2],
                        labelOf: (item) => [
                          'GitHub 官方',
                          'gh-proxy.com',
                          '一个很长的自定义线路名称用于验证菜单不会越界',
                        ][item],
                        width: 164,
                        menuWidth: 260,
                        wrapMenuLabels: true,
                        onChanged: (next) => setState(() => value = next),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.byKey(const ValueKey('select')));
          await tester.pumpAndSettle();
          final option = find.byKey(const ValueKey('shell-select-option-1'));
          final rect = tester.getRect(option);
          expect(rect.left, greaterThanOrEqualTo(12));
          expect(rect.right, lessThanOrEqualTo(width - 12));
          expect(
            rect.bottom,
            lessThan(
              tester.getTopLeft(find.byKey(const ValueKey('select'))).dy,
            ),
          );
          expect(find.byIcon(Icons.check_rounded), findsNothing);
          final selected = find.byKey(const ValueKey('shell-select-option-0'));
          final selectedPalette = AppPalette.of(tester.element(selected));
          final selectedPaint = tester.widget<AnimatedContainer>(
            find.descendant(
              of: selected,
              matching: find.byType(AnimatedContainer),
            ),
          );
          expect(selectedPaint.foregroundDecoration, isNull);
          await captureDesktopUi(tester, 'select-selected-$width-$dark');
          expect(
            (selectedPaint.decoration as BoxDecoration).color,
            selectedPalette.selected,
          );
          final selectedLabel = tester.widget<Text>(
            find.descendant(of: selected, matching: find.byType(Text)).first,
          );
          expect(selectedLabel.style!.color, selectedPalette.ink);
          expect(selectedLabel.style!.fontWeight, FontWeight.w600);
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer();
          await mouse.moveTo(tester.getCenter(option));
          await tester.pumpAndSettle();
          final paint = tester.widget<AnimatedContainer>(
            find.descendant(
              of: option,
              matching: find.byType(AnimatedContainer),
            ),
          );
          expect(
            (paint.decoration as BoxDecoration).color,
            AppPalette.of(tester.element(option)).hover,
          );
          await mouse.removePointer();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          final focusedPaint = tester.widget<AnimatedContainer>(
            find.descendant(
              of: option,
              matching: find.byType(AnimatedContainer),
            ),
          );
          expect(focusedPaint.foregroundDecoration, isNull);
          expect(
            (focusedPaint.decoration as BoxDecoration).color,
            selectedPalette.hover,
          );
          await captureDesktopUi(tester, 'select-keyboard-$width-$dark');
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(value, 1);
          expect(find.byType(AppMenuOption), findsNothing);
          // A value change returns keyboard focus to a neutral trigger;
          // focus and an open menu must not masquerade as a selected blue chip.
          BoxDecoration triggerDecoration() =>
              tester
                      .widget<AnimatedContainer>(
                        find.descendant(
                          of: find.byType(AppSelectTrigger),
                          matching: find.byType(AnimatedContainer),
                        ),
                      )
                      .decoration!
                  as BoxDecoration;
          final palette = AppPalette.of(
            tester.element(find.byType(AppSelectTrigger)),
          );
          expect(
            triggerDecoration().color,
            width < AppLayout.shellBreakpoint
                ? palette.controlSurface
                : palette.surface,
          );
          // Focus returns to the trigger after selection, so keyboard can reopen it.
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(find.byType(AppMenuOption), findsNWidgets(3));
          final keyboardSelected = find.byKey(
            const ValueKey('shell-select-option-1'),
          );
          final keyboardSelectionPaint = tester.widget<AnimatedContainer>(
            find.descendant(
              of: keyboardSelected,
              matching: find.byType(AnimatedContainer),
            ),
          );
          final keyboardSelectionColor =
              (keyboardSelectionPaint.decoration as BoxDecoration).color!;
          expect(
            keyboardSelectionColor,
            Color.alphaBlend(
              palette.focus.withValues(alpha: .12),
              palette.selected,
            ),
          );
          double contrast(Color foreground) {
            final first = foreground.computeLuminance();
            final second = keyboardSelectionColor.computeLuminance();
            return ((first > second ? first : second) + .05) /
                ((first > second ? second : first) + .05);
          }

          final keyboardSelectionLabel = tester.widget<Text>(
            find
                .descendant(of: keyboardSelected, matching: find.byType(Text))
                .first,
          );
          final keyboardSelectionCheck = tester.widget<Icon>(
            find.descendant(
              of: keyboardSelected,
              matching: find.byIcon(AppIcons.check),
            ),
          );
          expect(
            contrast(keyboardSelectionLabel.style!.color!),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(keyboardSelectionCheck.color!),
            greaterThanOrEqualTo(3),
          );
          expect(
            triggerDecoration().color,
            width < AppLayout.shellBreakpoint
                ? palette.controlSurface
                : palette.surface,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.byType(AppMenuOption), findsNothing);
          await tester.tap(find.byKey(const ValueKey('select')));
          await tester.pumpAndSettle();
          await tester.tapAt(const Offset(12, 12));
          await tester.pumpAndSettle();
          expect(find.byType(AppMenuOption), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final reduced in [false, true]) {
    testWidgets(
      'menu opens from its trigger edge without layout motion reduced=$reduced',
      (tester) async {
        tester.view.physicalSize = const Size(960, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: desktopCaptureTheme(
              AppTheme.light(),
            ).copyWith(platform: TargetPlatform.windows),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: RepaintBoundary(
                key: const ValueKey('desktop-ui-capture'),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AppShellSelect<int>(
                    value: 0,
                    items: const [0, 1, 2],
                    labelOf: (value) => '选项 $value',
                    menuWidth: 200,
                    alignMenuEnd: true,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(AppSelectTrigger));
        await tester.pump();
        final last = find.byKey(const ValueKey('shell-select-option-2'));
        final opening = tester.getRect(last);
        final fade = find.ancestor(of: last, matching: find.byType(Opacity));
        expect(tester.widget<Opacity>(fade).opacity, reduced ? 1 : 0);
        await tester.pump(const Duration(milliseconds: 50));
        if (!reduced) {
          expect(tester.widget<Opacity>(fade).opacity, greaterThan(0));
          expect(tester.widget<Opacity>(fade).opacity, lessThan(1));
          await captureDesktopUi(tester, 'select-opening-anchor');
        }
        await tester.pumpAndSettle();
        final settled = tester.getRect(last);
        // The bottom-right anchor stays at the trigger edge; only the small
        // paint scale changes, not menu layout or a translated popup position.
        expect(
          (opening.bottomRight - settled.bottomRight).distance,
          lessThan(.3),
        );
        expect(
          opening.width,
          reduced ? settled.width : lessThan(settled.width),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(find.byType(AppMenuOption), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  for (final dark in [false, true]) {
    testWidgets(
      'long wrapped select reveals its current value and follows keyboard traversal dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(960, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pageScroll = ScrollController(initialScrollOffset: 120);
        addTearDown(pageScroll.dispose);
        var value = 35;
        var changes = 0;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: child!,
            ),
            theme: desktopCaptureTheme(
              dark ? AppTheme.dark() : AppTheme.light(),
            ).copyWith(platform: TargetPlatform.windows),
            home: Scaffold(
              body: ListView(
                controller: pageScroll,
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 200),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StatefulBuilder(
                      builder: (context, setState) => AppShellSelect<int>(
                        value: value,
                        items: List.generate(60, (index) => index),
                        labelOf: (item) => item % 3 == 0
                            ? '学期 $item 一段用于验证换行后选中项定位的较长名称'
                            : '学期 $item',
                        wrapMenuLabels: true,
                        width: 168,
                        menuWidth: 240,
                        onChanged: (next) => setState(() {
                          value = next;
                          changes++;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 1000),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final pageOffset = pageScroll.offset;
        await tester.tap(find.byType(AppSelectTrigger));
        await tester.pumpAndSettle();
        void expectVisible(int index) {
          final row = tester.getRect(
            find.byKey(ValueKey('shell-select-option-$index')),
          );
          final viewport = tester.getRect(find.byType(SingleChildScrollView));
          expect(row.top, greaterThanOrEqualTo(viewport.top - .1));
          expect(row.bottom, lessThanOrEqualTo(viewport.bottom + .1));
        }

        expectVisible(35);
        await captureDesktopUi(tester, 'long-select-current-$dark');
        for (var i = 36; i <= 43; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expectVisible(i);
        }
        expect(pageScroll.offset, pageOffset);
        await captureDesktopUi(tester, 'long-select-keyboard-$dark');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(value, 43);
        expect(changes, 1);
        expect(find.byType(AppMenuOption), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
    testWidgets(
      'plain compact select blends into its host and keeps pointer and keyboard feedback dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(960, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final p = dark ? AppPalette.darkPalette : AppPalette.lightPalette;
        var value = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
            home: RepaintBoundary(
              key: const ValueKey('plain-select-capture'),
              child: Scaffold(
                backgroundColor: p.surface,
                body: Center(
                  child: StatefulBuilder(
                    builder: (context, setState) => AppShellSelect<int>(
                      plain: true,
                      compact: true,
                      width: 168,
                      value: value,
                      items: const [0, 1],
                      labelOf: (item) => item == 0 ? '最小化到托盘' : '退出程序',
                      onChanged: (next) => setState(() => value = next),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final trigger = find.byType(AppSelectTrigger);
        final rect = tester.getRect(trigger);
        final bodyPoint = Offset(rect.center.dx, rect.top + 4);
        final edgePoint = Offset(rect.left, rect.center.dy);
        Future<Color> pixel(Offset point) async => (await tester.runAsync(
          () async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('plain-select-capture')),
            );
            final image = await boundary.toImage();
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final bytes = data!.buffer.asUint8List();
            final at = (point.dy.floor() * image.width + point.dx.floor()) * 4;
            final color = Color.fromARGB(
              bytes[at + 3],
              bytes[at],
              bytes[at + 1],
              bytes[at + 2],
            );
            image.dispose();
            return color;
          },
        ))!;
        expect(await pixel(bodyPoint), p.surface);
        expect(await pixel(edgePoint), p.surface);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(rect.center);
        await tester.pumpAndSettle();
        expect(await pixel(bodyPoint), p.controlHover);
        expect(await pixel(edgePoint), isNot(p.surface));
        await mouse.down(rect.center);
        await tester.pumpAndSettle();
        expect(await pixel(bodyPoint), p.controlPressed);
        await mouse.up();
        await tester.pumpAndSettle();
        expect(find.byType(AppMenuOption), findsNWidgets(2));
        await mouse.removePointer();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(AppMenuOption), findsNothing);
        expect(await pixel(bodyPoint), p.surface);
        expect(await pixel(edgePoint), p.focus);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(AppMenuOption), findsNWidgets(2));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(value, 1);
        expect(find.byType(AppMenuOption), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  testWidgets('disabled select cannot open or change a value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppShellSelect<int>(
            value: 0,
            items: const [0, 1],
            labelOf: (value) => '$value',
            onChanged: null,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AppSelectTrigger));
    await tester.pumpAndSettle();
    expect(find.byType(AppMenuOption), findsNothing);
  });
  testWidgets('system back dismisses the menu before leaving its page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppShellSelect<int>(
            value: 0,
            items: const [0, 1],
            labelOf: (value) => '选项 $value',
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AppSelectTrigger));
    await tester.pumpAndSettle();
    expect(find.byType(AppMenuOption), findsNWidgets(2));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppMenuOption), findsNothing);
    expect(find.byType(AppSelectTrigger), findsOneWidget);
  });
  testWidgets(
    'truncated menu labels can show tooltips inside a nested navigator overlay',
    (tester) async {
      const longName = '用于验证菜单内长名称悬浮提示的非常长课程名称';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Row(
              children: [
                const SizedBox(width: 220),
                Expanded(
                  child: Navigator(
                    onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => Align(
                        alignment: Alignment.topRight,
                        child: AppShellSelect<int>(
                          value: 0,
                          width: 150,
                          menuWidth: 180,
                          items: const [0, 1],
                          labelOf: (item) => item == 0 ? '全部课程' : longName,
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AppSelectTrigger));
      await tester.pumpAndSettle();
      final option = find.byKey(const ValueKey('shell-select-option-1'));
      expect(tester.getRect(option).left, greaterThan(220));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(option));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(longName), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'context menu shares inset hover and only runs actions after selection',
    (tester) async {
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PopupMenuButton<int>(
              onSelected: (_) => selected = true,
              itemBuilder: (_) => const [
                AppPopupMenuItem<int>(
                  value: 1,
                  label: '删除',
                  icon: Icons.delete_outline,
                  danger: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      expect(selected, isFalse);
      final option = find.byType(AppMenuOption);
      final entry = find.byType(AppPopupMenuItem<int>);
      expect(
        tester.getRect(option).left,
        greaterThan(tester.getRect(entry).left),
      );
      expect(
        tester.getRect(option).right,
        lessThan(tester.getRect(entry).right),
      );
      Focus.of(tester.element(find.text('删除'))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(find.byType(AppMenuOption), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
