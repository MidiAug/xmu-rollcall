import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_grading_page.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_mobile_assignment_page.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_providers.dart';
import '../fixtures/ta_http_fixture.dart';
import '../fixtures/preview_fonts.dart';
import '../fixtures/desktop_ui_capture.dart';

void main() {
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  for (final entry in [
    (320.0, TargetPlatform.android),
    (390.0, TargetPlatform.iOS),
    (900.0, TargetPlatform.android),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('mobile readonly route ${entry.$1} ${entry.$2} dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = Size(entry.$1, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = TaHttpFixture();
        final repo = await f.repository();
        addTearDown(repo.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taRepositoryProvider.overrideWith((ref) async => repo),
              currentTeachingCoursesProvider.overrideWith(
                (ref) async => const [
                  CatalogCourse(
                    id: '91',
                    title: '研究生课程：写作与学术实践',
                    roles: ['instructor_assistant'],
                  ),
                ],
              ),
            ],
            child: RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: MaterialApp(
                theme: desktopCaptureTheme(
                  (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                    platform: entry.$2,
                  ),
                ),
                home: const Scaffold(body: TaGradingPage()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('研究生课程：写作与学术实践'), findsOneWidget);
        expect(find.text('助教作业'), findsOneWidget);
        await captureDesktopUi(tester, 'ta-mobile-list-${entry.$1}-$dark');
        await tester.tap(find.text(TaHttpFixture.title));
        await tester.pumpAndSettle();
        expect(find.byType(TaMobileAssignmentPage), findsOneWidget);
        expect(find.text('示例学生1'), findsOneWidget);
        expect(find.text('导入 CSV'), findsNothing);
        expect(find.text('下载打包'), findsNothing);
        expect(find.byType(Checkbox), findsNothing);
        await tester.tap(find.byTooltip('核对成绩').first);
        await tester.pumpAndSettle();
        expect(f.requests.every((r) => r.method == 'GET'), isTrue);
        expect(f.requests.where((r) => r.uri.path.contains('/zip')), isEmpty);
        expect(
          f.requests.any((r) => r.uri.path.endsWith('/score-records')),
          isTrue,
        );
        await captureDesktopUi(tester, 'ta-mobile-detail-${entry.$1}-$dark');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
  testWidgets(
    'no courses shows dedicated empty state without assignment requests',
    (tester) async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taRepositoryProvider.overrideWith((ref) async => repo),
            currentTeachingCoursesProvider.overrideWith(
              (ref) async => const [],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: TaGradingPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('还没有助教课程'), findsOneWidget);
      expect(f.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('mobile retry revalidates course before reading students', (
    tester,
  ) async {
    final f = TaHttpFixture();
    final repo = await f.repository();
    addTearDown(repo.dispose);
    var wrongCourse = true;
    f.intercept = (o) async => o.uri.path == '/api/activities/81' && wrongCourse
        ? TaHttpFixture.response({...f.assignment, 'course_id': 92})
        : null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taRepositoryProvider.overrideWith((ref) async => repo),
          currentTeachingCoursesProvider.overrideWith(
            (ref) async => const [CatalogCourse(id: '91', title: '课程一')],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          home: const Scaffold(body: TaGradingPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(TaHttpFixture.title));
    await tester.pumpAndSettle();
    expect(f.requests.any((o) => o.uri.path.endsWith('/students')), isFalse);
    wrongCourse = false;
    await tester.tap(find.text('重新加载'));
    await tester.pumpAndSettle();
    expect(find.text('示例学生1'), findsOneWidget);
    expect(
      f.requests.where((o) => o.uri.path == '/api/activities/81'),
      hasLength(2),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'only multiple courses reveal switching; selected course drives requests',
    (tester) async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taRepositoryProvider.overrideWith((ref) async => repo),
            currentTeachingCoursesProvider.overrideWith(
              (ref) async => const [
                CatalogCourse(id: '91', title: '课程一'),
                CatalogCourse(id: '92', title: '课程二'),
              ],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: TaGradingPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('课程一'), findsNWidgets(2));
      await tester.tap(find.text('课程二'));
      await tester.pumpAndSettle();
      expect(find.text('课程二'), findsNWidgets(2));
      expect(f.requests.last.uri.path, '/api/courses/92/homework-activities');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
