import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_form_controls.dart';
import 'package:xmu_rollcall/app/app_hierarchy_choice_page.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/logistics/logistics_form_models.dart';
import '../fixtures/desktop_ui_capture.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(loadDesktopUiCaptureFonts);
  final choices = logisticsChoices([
    for (final campus in ['思明', '翔安', '漳州'])
      {
        'id': campus,
        'name': '$campus校区-学生公寓',
        'children': [
          for (var i = 1; i <= 122; i++)
            {'id': '$campus-$i', 'name': '公寓${i.toString().padLeft(3, '0')}'},
        ],
      },
  ]);
  for (final width in [320.0, 1104.0]) {
    for (final dark in [false, true]) {
      testWidgets('hierarchy and global search $width $dark', (tester) async {
        tester.view.physicalSize = Size(width, 840);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        LogisticsChoice? result;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: desktopCaptureTheme(
              (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                platform: width < 500
                    ? TargetPlatform.android
                    : TargetPlatform.windows,
              ),
            ),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width < 500 ? 1.3 : 1),
                ),
                child: child!,
              ),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: AppButton(
                  label: '选择区域',
                  onPressed: () async {
                    result = await Navigator.of(context).push<LogisticsChoice>(
                      MaterialPageRoute(
                        builder: (_) => AppHierarchyChoicePage(
                          title: '故障区域',
                          items: choices,
                          pathOf: (v) => v.path,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('选择区域'));
        await tester.pumpAndSettle();
        expect(find.text('公寓001'), findsNothing);
        await captureDesktopUi(
          tester,
          'logistics-region-campuses-$width-$dark',
        );
        await tester.tap(find.text('思明校区'));
        await tester.pumpAndSettle();
        expect(find.text('学生公寓'), findsOneWidget);
        await tester.tap(find.text('学生公寓'));
        await tester.pumpAndSettle();
        expect(find.text('公寓001'), findsOneWidget);
        expect(result, isNull);
        await captureDesktopUi(
          tester,
          'logistics-region-buildings-$width-$dark',
        );
        // Search spans the whole data set, including other campuses with the
        // same leaf names. Choosing a result returns the exact wire identity.
        await tester.enterText(find.byType(TextField), '翔安 122');
        await tester.pumpAndSettle();
        expect(find.text('公寓122'), findsOneWidget);
        expect(find.text('翔安校区 / 学生公寓'), findsOneWidget);
        await captureDesktopUi(tester, 'logistics-region-search-$width-$dark');
        await tester.tap(find.text('公寓122'));
        await tester.pumpAndSettle();
        expect(result?.id, '翔安-122');
        expect(result?.label, '翔安校区-学生公寓/公寓122');
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('breadcrumb changes branch and keyboard chooses a leaf', (
    tester,
  ) async {
    LogisticsChoice? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: AppButton(
              label: '打开',
              onPressed: () async {
                result = await Navigator.of(context).push<LogisticsChoice>(
                  MaterialPageRoute(
                    builder: (_) => AppHierarchyChoicePage(
                      title: '选择项目',
                      items: choices,
                      pathOf: (v) => v.path,
                      selected: choices[100],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('公寓101').hitTestable(), findsOneWidget);
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.text('公寓001'), findsNothing);
    await tester.enterText(find.byType(TextField), '不存在');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的选项'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '漳州 121');
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.text('公寓121'))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result?.id, '漳州-121');
    expect(find.byType(AppHierarchyChoicePage<LogisticsChoice>), findsNothing);
  });
}
