import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_form_controls.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

void main() {
  testWidgets(
    'search clear updates the query and external identity reset is visible',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final queries = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: AppSearchField(
              hintText: '搜索学生',
              controller: controller,
              onChanged: queries.add,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '0007');
      await tester.pump();
      expect(queries, ['0007']);
      await tester.tap(find.byTooltip('清空搜索'));
      await tester.pump();
      expect(queries, ['0007', '']);
      expect(controller.text, isEmpty);
      expect(find.byTooltip('清空搜索'), findsNothing);
      await tester.enterText(find.byType(TextField), '林同学');
      await tester.pump();
      controller.clear();
      await tester.pump();
      expect(find.byTooltip('清空搜索'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('busy action blocks pointer and keyboard repeat until released', (
    tester,
  ) async {
    var busy = false;
    var calls = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, set) {
                update = set;
                return AppButton(
                  label: '提交成绩',
                  busy: busy,
                  onPressed: () => calls++,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
    update(() => busy = true);
    await tester.pump();
    await tester.tap(find.byType(AppButton));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    update(() => busy = false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交成绩'));
    expect(calls, 2);
  });
}
