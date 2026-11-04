import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

void main() {
  testWidgets('table action supports pointer, keyboard and disabled state', (
    tester,
  ) async {
    var calls = 0;
    Future<void> show(bool enabled) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppTableAction(
            label: '未批改',
            tooltip: '核对学生成绩',
            onPressed: enabled ? () => calls++ : null,
          ),
        ),
      ),
    );
    await show(true);
    await tester.tap(find.text('未批改'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(calls, 3);
    await show(false);
    await tester.tap(find.text('未批改'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 3);
  });
}
