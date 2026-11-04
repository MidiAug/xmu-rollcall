import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_grading_page.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_providers.dart';
import '../fixtures/ta_http_fixture.dart';
import '../fixtures/preview_fonts.dart';
import '../fixtures/desktop_ui_capture.dart';

void main() {
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  for (final width in [320.0, 1100.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'assignment list, selection and CSV preview fit $width dark=$dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 950);
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
                      title: '研究生课程，长课程名称需要省略显示便于选择',
                      roles: ['instructor_assistant'],
                    ),
                  ],
                ),
                taCsvReaderProvider.overrideWithValue(
                  () async => 'user_no,score\n0001,86\n0002,0',
                ),
              ],
              child: RepaintBoundary(
                key: const ValueKey('desktop-ui-capture'),
                child: MaterialApp(
                  theme: desktopCaptureTheme(
                    dark ? AppTheme.dark() : AppTheme.light(),
                  ),
                  home: const Scaffold(body: TaGradingPage()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('已提交 2'), findsOneWidget);
          expect(find.text('已批改 0'), findsOneWidget);
          await captureDesktopUi(tester, 'ta-list-$width-$dark');
          await tester.tap(find.text(TaHttpFixture.title));
          await tester.pumpAndSettle();
          expect(find.text('示例学生1  0001'), findsOneWidget);
          await tester.tap(find.text('选择已提交学生'));
          await tester.pumpAndSettle();
          expect(find.text('已选 2 人'), findsOneWidget);
          await captureDesktopUi(tester, 'ta-students-$width-$dark');
          await tester.scrollUntilVisible(
            find.text('导入 CSV'),
            250,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('ta-assignment-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('导入 CSV'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('预览确认并提交'),
            250,
            scrollable: find
                .descendant(
                  of: find.byKey(const ValueKey('ta-assignment-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('共 2 行，错误 0 行'), findsOneWidget);
          expect(f.requests.where((r) => r.method == 'PUT'), isEmpty);
          await captureDesktopUi(tester, 'ta-csv-$width-$dark');
          await tester.tap(find.text('预览确认并提交'));
          await tester.pumpAndSettle();
          expect(find.text('确认提交成绩'), findsOneWidget);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          expect(f.requests.where((r) => r.method == 'PUT'), isEmpty);
          await tester.tap(find.text('预览确认并提交'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('确认提交').last);
          await tester.pumpAndSettle();
          expect(f.scores, {1: 86, 2: 0});
          expect(find.textContaining('已保存 2 行'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
  testWidgets(
    'repack hides previous ready URL until a new server package is ready',
    (tester) async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taRepositoryProvider.overrideWith((ref) async => repo),
            currentTeachingCoursesProvider.overrideWith(
              (ref) async => const [CatalogCourse(id: '91', title: '测试课程')],
            ),
          ],
          child: MaterialApp(home: const Scaffold(body: TaGradingPage())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(TaHttpFixture.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择已提交学生'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('重新打包'),
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('ta-assignment-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('重新打包'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(f.packed, isTrue);
      var download = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '下载打包'),
      );
      expect(download.onPressed, isNull);
      final post = f.requests.singleWhere((r) => r.method == 'POST');
      expect((post.data as Map)['ids'], [1, 2]);
      f.zip = {'id': 72, 'status': 'ready', 'key': 'b' * 40};
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      download = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '下载打包'),
      );
      expect(download.onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'identity provider replacement hides old roster and cancels page session',
    (tester) async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      final container = ProviderContainer(
        overrides: [
          taRepositoryProvider.overrideWith((ref) async {
            ref.onDispose(repo.dispose);
            return repo;
          }),
          currentTeachingCoursesProvider.overrideWith(
            (ref) async => const [CatalogCourse(id: '91', title: '测试课程')],
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: const Scaffold(body: TaGradingPage())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(TaHttpFixture.title));
      await tester.pumpAndSettle();
      container.invalidate(taRepositoryProvider);
      await tester.pumpAndSettle();
      expect(find.text('示例学生1  0001'), findsNothing);
      expect(repo.active, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
