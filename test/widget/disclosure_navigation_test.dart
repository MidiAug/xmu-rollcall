import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'group disclosure keeps hidden actions out of traversal dark=$dark',
      (tester) async {
        tester.view.physicalSize = Size(dark ? 320 : 960, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final after = FocusNode();
        addTearDown(after.dispose);
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: Scaffold(
              body: Column(
                children: [
                  SettingsSection(
                    padTop: false,
                    hasLeading: false,
                    children: [
                      AppDisclosure(
                        headerKey: const ValueKey('disclosure-header'),
                        title: '计算规则与来源',
                        subtitle: '仅在需要时展开查看计算口径',
                        children: [
                          TextButton(
                            onPressed: () => opened++,
                            child: const Text('查看来源'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TextButton(
                    focusNode: after,
                    onPressed: () {},
                    child: const Text('下一项'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('查看来源'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final header = Focus.of(tester.element(find.text('计算规则与来源')));
        expect(header.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(after.hasFocus, isTrue);
        header.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(opened, 1);
        // Reversing while opening/closing must settle back to the requested state.
        await tester.tap(find.byKey(const ValueKey('disclosure-header')));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(find.byKey(const ValueKey('disclosure-header')));
        await tester.pumpAndSettle();
        expect(find.text('查看来源'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('disclosure-header')));
        await tester.pumpAndSettle();
        expect(find.text('查看来源'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
