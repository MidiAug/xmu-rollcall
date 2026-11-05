import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

void main() {
  testWidgets('preference label and keyboard toggle one shared selection', (
    tester,
  ) async {
    var value = false;
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, set) => AppCheckboxRow(
              label: '允许覆盖已有成绩',
              value: value,
              onChanged: (next) => set(() {
                value = next;
                changes++;
              }),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('允许覆盖已有成绩'));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(changes, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(value, isFalse);
    expect(changes, 2);
  });
  testWidgets('mixed selection, keyboard and pointer follow the owner value', (
    tester,
  ) async {
    bool? value;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: AppCheckbox(
              value: value,
              label: '全选当前列表',
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    final checkbox = find.byType(AppCheckbox);
    expect(
      tester.getSemantics(checkbox),
      matchesSemantics(
        label: '全选当前列表',
        hasCheckedState: true,
        isCheckStateMixed: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    semantics.dispose();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(value, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(value, isFalse);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });

  testWidgets(
    'disabled checkbox cannot activate, controlled value stays with owner',
    (tester) async {
      var calls = 0;
      Future<void> show(ValueChanged<bool>? onChanged) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: AppCheckbox(
              value: false,
              label: '选择学生',
              onChanged: onChanged,
            ),
          ),
        ),
      );
      await show((_) => calls++);
      await tester.tap(find.byType(AppCheckbox));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        tester.widget<AppCheckbox>(find.byType(AppCheckbox)).value,
        isFalse,
      );
      await show(null);
      await tester.tap(find.byType(AppCheckbox));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(calls, 1);
    },
  );
}
