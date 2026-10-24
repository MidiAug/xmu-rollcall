import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/monitor/detection_window_editor.dart';
import '../fixtures/desktop_ui_capture.dart';

void main() {
  setUpAll(loadDesktopUiCaptureFonts);
  for (final scenario in [
    (width: 960.0, dark: false, scale: 1.0, keyboard: 0.0),
    (width: 960.0, dark: true, scale: 1.0, keyboard: 0.0),
    (width: 384.0, dark: false, scale: 1.0, keyboard: 0.0),
    (width: 320.0, dark: true, scale: 1.3, keyboard: 300.0),
  ]) {
    final name =
        '${scenario.width.toInt()}-${scenario.dark ? 'dark' : 'light'}';
    testWidgets(
      'daily range validates, describes midnight and stays reachable at $name',
      (tester) async {
        tester.view.physicalSize = Size(scenario.width, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        DetectionWindow? result;
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('desktop-ui-capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: desktopCaptureTheme(
                scenario.dark ? AppTheme.dark() : AppTheme.light(),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scenario.scale),
                  viewInsets: EdgeInsets.only(bottom: scenario.keyboard),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showDetectionWindowEditor(
                        context,
                        const DetectionWindow(enabled: true),
                      );
                    },
                    child: const Text('编辑'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        expect(find.text('开始时间'), findsOneWidget);
        expect(find.text('结束时间'), findsOneWidget);
        await captureDesktopUi(tester, 'time-$name');
        if (scenario.keyboard > 0) {
          await tester.ensureVisible(find.text('保存'));
          await tester.pumpAndSettle();
          await captureDesktopUi(tester, 'time-$name-actions');
        }

        Future<void> input(int index, String text) async {
          final field = find.byKey(ValueKey('window-time-$index'));
          await tester.ensureVisible(field);
          await tester.enterText(field, text);
        }

        Future<void> save() async {
          await tester.ensureVisible(find.text('保存'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('保存'));
          await tester.pumpAndSettle();
        }

        await input(0, '25');
        await save();
        expect(find.textContaining('请输入有效时间'), findsOneWidget);
        expect(result, isNull);
        await input(0, '22');
        await input(1, '00');
        await save();
        expect(find.text('开始和结束时间不能相同'), findsOneWidget);
        await input(2, '07');
        await input(3, '30');
        await tester.pumpAndSettle();
        expect(find.text('每天 22:00 至次日 07:30'), findsOneWidget);
        await save();
        expect(result!.startMinute, 1320);
        expect(result!.endMinute, 450);
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();
        result = null;
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(
        scenario.width >= 600 ? TargetPlatform.windows : TargetPlatform.android,
      ),
    );
  }
}
