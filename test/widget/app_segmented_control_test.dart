import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  setUpAll(loadDesktopPreviewFonts);
  for (final dark in [false, true]) {
    for (final narrow in [false, true]) {
      testWidgets(
        'disabled segments retain selection and reject pointer keys dark=$dark narrow=$narrow',
        (tester) async {
          tester.view.physicalSize = Size(narrow ? 390 : 960, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          var calls = 0;
          var selected = 1;
          var enabled = false;
          late StateSetter rebuild;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: Scaffold(
                body: Center(
                  child: StatefulBuilder(
                    builder: (context, set) {
                      rebuild = set;
                      return AppSegmentedControl<int>(
                        enabled: enabled,
                        segments: const [
                          AppSegment(value: 0, label: '协助码'),
                          AppSegment(value: 1, label: '学号密码'),
                        ],
                        value: selected,
                        onChanged: (value) => set(() {
                          selected = value;
                          calls++;
                        }),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final control = find.byType(AppSegmentedControl<int>);
          final before = tester.getRect(control);
          final flags = tester
              .getSemantics(find.byKey(const ValueKey(1)))
              .getSemanticsData()
              .flagsCollection;
          expect(flags.isSelected, ui.Tristate.isTrue);
          expect(flags.isEnabled, ui.Tristate.isFalse);
          await tester.tap(find.text('协助码'));
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          expect(calls, 0);
          expect(selected, 1);
          expect(
            find.byKey(const ValueKey('segment-selection')),
            findsOneWidget,
          );
          expect(tester.getRect(control), before);
          rebuild(() => enabled = true);
          await tester.pumpAndSettle();
          await tester.tap(find.text('协助码'));
          await tester.pumpAndSettle();
          expect(calls, 1);
          expect(selected, 0);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
}
