import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

void main() {
  testWidgets(
    'touch choice reveals current item, saves selection and cancels safely',
    (tester) async {
      tester.view.physicalSize = const Size(384, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var value = 45;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, rebuild) => AppToolbarChoice<int>(
                title: '选择范围',
                value: value,
                items: List.generate(60, (i) => i),
                labelOf: (item) => '选项$item',
                onChanged: (next) => rebuild(() => value = next),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AppToolbarChoice<int>));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
        isFalse,
      );
      expect(find.text('选项45').hitTestable(), findsOneWidget);
      await tester.tap(find.text('选项46').hitTestable());
      await tester.pumpAndSettle();
      expect(value, 46);
      await tester.tap(find.byType(AppToolbarChoice<int>));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(value, 46);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byType(AppToolbarChoice<int>));
      await tester.pumpAndSettle();
      AppShellSelect.closeAll();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disposing an open choice does not look up a deactivated context',
    (tester) async {
      tester.view.physicalSize = const Size(384, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppShellSelect<int>(
              value: 1,
              items: const [1, 2],
              labelOf: (item) => '$item',
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byType(AppShellSelect<int>));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
