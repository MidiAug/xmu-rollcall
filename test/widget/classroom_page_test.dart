import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/classrooms/classroom_page.dart';
import 'package:xmu_rollcall/features/classrooms/classroom_providers.dart';
import '../fixtures/classroom_fixture.dart';
import '../fixtures/desktop_ui_capture.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(loadDesktopUiCaptureFonts);
  Future<void> pump(
    WidgetTester tester,
    ClassroomFixtureClient client, {
    double width = 1104,
    bool dark = false,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          browserIdentityProvider.overrideWithValue((
            ownerId: 1,
            userId: 1,
            assistId: null,
          )),
          classroomClientFactoryProvider.overrideWithValue(() => client),
          academicIdentityResolverProvider.overrideWithValue(
            (uid) async => AcademicIdentity(
              username: '20260000000001',
              isCurrent: () async => true,
            ),
          ),
        ],
        child: MaterialApp(
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
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width == 320 ? 1.3 : 1)),
              child: child!,
            ),
          ),
          home: const ClassroomsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.last);
    await tester.pumpAndSettle();
    await tester.tap(f.last);
    await tester.pumpAndSettle();
  }

  Finder confirm(String label) => find.descendant(
    of: find.byType(AppDialogFrame),
    matching: find.widgetWithText(FilledButton, label),
  );
  for (final width in [320.0, 390.0, 1104.0]) {
    for (final dark in [false, true]) {
      testWidgets('native classroom hub $width $dark', (tester) async {
        final c = ClassroomFixtureClient();
        await pump(tester, c, width: width, dark: dark);
        expect(find.text('厦大教室'), findsOneWidget);
        expect(c.homeCount, 1);
        expect(find.text('座位预约'), findsOneWidget);
        await captureDesktopUi(tester, 'classroom-home-$width-$dark');
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
    'seat booking loads rules and availability, confirms and cancels explicitly',
    (tester) async {
      final c = ClassroomFixtureClient();
      await pump(tester, c, width: 390);
      await press(tester, find.text('座位预约'));
      await press(tester, find.text('测试自习室'));
      expect(find.text('A01'), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'A02'))
            .onPressed,
        isNull,
      );
      await captureDesktopUi(tester, 'classroom-seat-availability');
      await press(tester, find.text('A01'));
      await press(tester, find.byType(AppCheckboxRow));
      await press(tester, find.widgetWithText(AppButton, '确认预约'));
      expect(c.writes, isEmpty);
      await press(tester, find.text('取消'));
      expect(c.writes, isEmpty);
      await press(tester, find.widgetWithText(AppButton, '确认预约'));
      await press(tester, confirm('确认预约'));
      expect(c.writes, ['seat:1']);
    },
  );
  testWidgets('my booking cancellation is confirmed and refreshed', (
    tester,
  ) async {
    final c = ClassroomFixtureClient();
    await pump(tester, c);
    await press(tester, find.text('我的预约'));
    await press(tester, find.text('取消预约'));
    expect(c.writes, isEmpty);
    await press(tester, confirm('取消预约'));
    expect(c.writes, ['cancel']);
    expect(find.textContaining('已取消'), findsOneWidget);
  });
  for (final pair in [
    ('自习教室', '测试教室102'),
    ('讲座活动', '测试讲座1'),
    ('教室介绍', '测试楼101'),
    ('楼层索引', '测试教室103'),
    ('失物招领', '雨伞'),
  ]) {
    testWidgets('native ${pair.$1} reads its own resource', (tester) async {
      final c = ClassroomFixtureClient();
      await pump(tester, c);
      await press(tester, find.text(pair.$1));
      expect(find.text(pair.$2), findsOneWidget);
      await captureDesktopUi(tester, 'classroom-catalog-${pair.$1}');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('lecture pagination appends without detail requests', (
    tester,
  ) async {
    final c = ClassroomFixtureClient();
    await pump(tester, c);
    await press(tester, find.text('讲座活动'));
    await press(tester, find.text('加载更多'));
    expect(c.calls, ['lectures:1', 'lectures:2']);
    expect(find.text('测试讲座1'), findsOneWidget);
    expect(find.text('测试讲座2'), findsOneWidget);
  });
}
