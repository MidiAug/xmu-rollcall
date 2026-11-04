import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_service_tile.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/campus/campus_tools_page.dart';
import 'package:xmu_rollcall/features/campus/campus_calendar_page.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  testWidgets('service entry keyboard activation preserves geometry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 380,
            child: AppServiceTile(
              title: '学年校历',
              description: '学期安排与教学周',
              icon: Icons.calendar_month,
              accent: Colors.teal,
              onPressed: () => calls++,
            ),
          ),
        ),
      ),
    );
    final before = tester.getRect(find.byType(AppServiceTile));
    final icon = find
        .descendant(
          of: find.byType(AppServiceTile),
          matching: find.byType(Icon),
        )
        .first;
    final badge = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle,
    );
    expect(tester.getCenter(icon), tester.getCenter(badge));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.getRect(find.byType(AppServiceTile)), before);
  });
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  for (final width in [320.0, 760.0, 1104.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'directory equal tools and separate graduate section $width $dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 840);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: desktopCaptureTheme(
                (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: width == 320
                      ? TargetPlatform.android
                      : TargetPlatform.windows,
                ),
              ),
              builder: (context, child) => RepaintBoundary(
                key: const ValueKey('desktop-ui-capture'),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(width == 320 ? 1.3 : 1),
                  ),
                  child: child!,
                ),
              ),
              home: const Scaffold(body: CampusToolsPage()),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AppServiceTile), findsNWidgets(5));
          expect(find.text('常用工具'), findsOneWidget);
          expect(find.text('研究生'), findsOneWidget);
          expect(find.text('校园地图、考试安排、成绩计算与助教工具'), findsNothing);
          final map = tester.getSize(
            find.byKey(const ValueKey('tool-campus-map')),
          );
          final exam = tester.getSize(find.byKey(const ValueKey('tool-exams')));
          expect(map, exam);
          await captureDesktopUi(tester, 'tools-directory-$width-$dark');
          await tester.ensureVisible(find.text('学年校历'));
          await tester.tap(find.text('学年校历'));
          await tester.pumpAndSettle();
          expect(find.byType(CampusCalendarPage), findsOneWidget);
          expect(find.text('第一学期'), findsOneWidget);
          expect(find.text('短学期'), findsOneWidget);
          await captureDesktopUi(tester, 'calendar-$width-$dark');
          await tester.tap(find.byTooltip('返回'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('研究生'));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final date in [
    DateTime(2026, 11, 4),
    DateTime(2027, 1, 10),
    DateTime(2030, 11, 1),
  ]) {
    testWidgets('calendar boundaries use maintained data $date', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: CampusCalendarPage(today: date),
        ),
      );
      await tester.pumpAndSettle();
      if (date.year == 2026) {
        expect(find.text('当前第 9 周'), findsOneWidget);
        await tester.tap(find.byType(AppShellSelect<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('shell-select-option-1')));
        await tester.pumpAndSettle();
        expect(find.textContaining('2025—2026'), findsOneWidget);
      } else {
        expect(find.textContaining('当前第'), findsNothing);
      }
      if (date.year == 2030) {
        expect(find.textContaining('尚未维护'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
