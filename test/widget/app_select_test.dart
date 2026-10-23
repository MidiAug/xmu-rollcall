import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

void main() {
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
              theme: dark ? AppTheme.dark() : AppTheme.light(),
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
          expect(find.byIcon(Icons.check_rounded), findsOneWidget);
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
          expect(triggerDecoration().color, palette.content);
          // Focus returns to the trigger after selection, so keyboard can reopen it.
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(find.byType(AppMenuOption), findsNWidgets(3));
          expect(triggerDecoration().color, palette.content);
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
