import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_assignment_store.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_grading_page.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_mobile_assignment_page.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_models.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_providers.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_widgets.dart';
import '../fixtures/ta_http_fixture.dart';
import '../fixtures/preview_fonts.dart';
import '../fixtures/desktop_ui_capture.dart';

void main() {
  initializeDesktopUiCapture();
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
                    (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                      platform: TargetPlatform.windows,
                    ),
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
          expect(find.text('示例学生1'), findsOneWidget);
          final headerY = tester.getTopLeft(find.text('姓名')).dy;
          await tester.tap(find.byKey(const ValueKey('ta-select-1')));
          await tester.tap(find.byKey(const ValueKey('ta-select-2')));
          await tester.pumpAndSettle();
          expect(find.text('已选 2 人'), findsOneWidget);
          expect(tester.getTopLeft(find.text('姓名')).dy, headerY);
          await captureDesktopUi(tester, 'ta-students-$width-$dark');
          await tester.tap(find.text('导入成绩'));
          await tester.pumpAndSettle();
          expect(find.text('复制模板'), findsOneWidget);
          expect(
            find.widgetWithText(FilledButton, '选择 CSV 文件'),
            findsOneWidget,
          );
          if (width > 600) {
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('ta-csv-content')))
                  .width,
              lessThanOrEqualTo(480),
            );
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('ta-csv-content')))
                  .height,
              lessThan(400),
            );
          }
          await captureDesktopUi(tester, 'ta-csv-import-$width-$dark');
          await tester.tap(find.text('选择 CSV 文件'));
          await tester.pumpAndSettle();
          expect(find.textContaining('共 2 行，错误 0 行'), findsOneWidget);
          expect(f.requests.where((r) => r.method == 'PUT'), isEmpty);
          await captureDesktopUi(tester, 'ta-csv-$width-$dark');
          await tester.tap(find.text('提交成绩'));
          await tester.pumpAndSettle();
          expect(find.text('确认提交成绩'), findsOneWidget);
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          expect(f.requests.where((r) => r.method == 'PUT'), isEmpty);
          await tester.tap(find.text('提交成绩'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('确认提交').last);
          await tester.pumpAndSettle();
          expect(f.scores, {1: 86, 2: 0});
          expect(find.textContaining('已保存 2 行'), findsOneWidget);
          expect(find.textContaining('已批改 2'), findsOneWidget);
          await tester.tap(find.byTooltip('关闭'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('返回'));
          await tester.pumpAndSettle();
          expect(find.text('已批改 2'), findsOneWidget);
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
      const launchChannel = MethodChannel('plugins.flutter.io/url_launcher');
      final launched = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launchChannel,
        (call) async {
          if (call.method == 'launch') {
            launched.add((call.arguments as Map)['url'] as String);
          }
          return true;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          launchChannel,
          null,
        ),
      );
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
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            home: const Scaffold(body: TaGradingPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(TaHttpFixture.title));
      await tester.pumpAndSettle();
      final actionRect = tester.getRect(find.byKey(const ValueKey('ta-pack')));
      await tester.tap(find.byKey(const ValueKey('ta-pack')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(f.packed, isTrue);
      expect(find.text('下载打包'), findsNothing);
      final post = f.requests.singleWhere((r) => r.method == 'POST');
      expect((post.data as Map)['ids'], [1, 2]);
      f.zip = {'id': 72, 'status': 'ready', 'key': 'b' * 40};
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final download = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '下载打包'),
      );
      expect(download.onPressed, isNotNull);
      expect(tester.getRect(find.byKey(const ValueKey('ta-pack'))), actionRect);
      await tester.tap(find.text('下载打包'));
      await tester.pumpAndSettle();
      expect(launched, [
        'https://c-media.xmu.edu.cn/download/file/${'b' * 40}',
      ]);
      expect(f.requests.where((r) => r.method == 'POST'), hasLength(1));
      await tester.tap(find.byTooltip('下载选项'));
      await tester.pumpAndSettle();
      expect(find.text('重新打包当前范围'), findsOneWidget);
      await tester.tap(find.text('重新打包当前范围'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(f.requests.where((r) => r.method == 'POST'), hasLength(2));
      expect(find.text('下载打包'), findsNothing);
      expect(
        tester
            .widget<AppButton>(find.byKey(const ValueKey('ta-pack')))
            .onPressed,
        isNull,
      );
      f.zip = {'id': 73, 'status': 'ready', 'key': 'c' * 40};
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('下载打包'), findsOneWidget);
      expect(tester.getRect(find.byKey(const ValueKey('ta-pack'))), actionRect);
      await tester.tap(find.byKey(const ValueKey('ta-select-3')));
      await tester.pumpAndSettle();
      expect(find.text('下载打包'), findsNothing);
      expect(
        tester
            .widget<AppButton>(find.byKey(const ValueKey('ta-pack')))
            .onPressed,
        isNull,
      );
      expect(f.requests.where((r) => r.method == 'POST'), hasLength(2));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  for (final manuallySelected in [false, true]) {
    testWidgets(
      'pack scope ignores search and filters, explicit selection=$manuallySelected',
      (tester) async {
        final f = TaHttpFixture();
        final repo = await f.repository();
        addTearDown(repo.dispose);
        tester.view.physicalSize = const Size(1100, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taRepositoryProvider.overrideWith((ref) async => repo),
              currentTeachingCoursesProvider.overrideWith(
                (ref) async => const [CatalogCourse(id: '91', title: '测试课程')],
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light().copyWith(
                platform: TargetPlatform.windows,
              ),
              home: const Scaffold(body: TaGradingPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(TaHttpFixture.title));
        await tester.pumpAndSettle();
        final search = find.descendant(
          of: find.byType(AppSearchField),
          matching: find.byType(TextField),
        );
        final headerY = tester.getTopLeft(find.text('姓名')).dy;
        if (manuallySelected) {
          await tester.tap(find.byKey(const ValueKey('ta-select-1')));
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(find.text('姓名')).dy, headerY);
          await tester.enterText(search, '示例学生3');
          await tester.pumpAndSettle();
          expect(find.text('已选 1 人'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('ta-select-all')));
          await tester.pumpAndSettle();
          expect(find.text('已选 2 人'), findsOneWidget);
        } else {
          await tester.enterText(search, '示例学生3');
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const ValueKey('ta-submission-filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('shell-select-option-2')));
        await tester.pumpAndSettle();
        expect(find.text('显示 1 人'), findsOneWidget);
        expect(tester.widget<TextField>(search).controller!.text, '示例学生3');
        expect(tester.getTopLeft(find.text('姓名')).dy, headerY);
        final readsBeforePack = f.requests.length;
        await tester.tap(find.byKey(const ValueKey('ta-pack')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final post = f.requests.singleWhere((r) => r.method == 'POST');
        expect((post.data as Map)['ids'], manuallySelected ? [1] : [1, 2]);
        expect((post.data as Map)['all_ids'], [1, 2, 3]);
        expect(
          f.requests
              .skip(readsBeforePack)
              .where((r) => r.uri.path.endsWith('/score-records')),
          isEmpty,
        );
        final postCount = f.requests.where((r) => r.method == 'POST').length;
        await tester.tap(find.byKey(const ValueKey('ta-pack')));
        await tester.pump();
        expect(f.requests.where((r) => r.method == 'POST').length, postCount);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        final requestsAfterClose = f.requests.length;
        await tester.pump(const Duration(seconds: 10));
        expect(f.requests.length, requestsAfterClose);
      },
    );
  }
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
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            home: const Scaffold(body: TaGradingPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(TaHttpFixture.title));
      await tester.pumpAndSettle();
      container.invalidate(taRepositoryProvider);
      await tester.pumpAndSettle();
      expect(find.text('示例学生1'), findsNothing);
      expect(repo.active, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      '111 students remain the primary content at screenshot size dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(928, 738);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = TaHttpFixture(studentCount: 111, submittedCount: 47);
        final repo = await f.repository();
        addTearDown(repo.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taRepositoryProvider.overrideWith((ref) async => repo),
              currentTeachingCoursesProvider.overrideWith(
                (ref) async => const [CatalogCourse(id: '91', title: '示例课程')],
              ),
            ],
            child: RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: MaterialApp(
                theme: desktopCaptureTheme(
                  (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                    platform: TargetPlatform.windows,
                  ),
                ),
                home: const Scaffold(body: TaGradingPage()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(TaHttpFixture.title));
        await tester.pumpAndSettle();
        expect(find.text(TaHttpFixture.title), findsOneWidget);
        expect(find.text('提交进度'), findsNothing);
        expect(find.text('CSV 批量评分'), findsNothing);
        expect(find.text('打包全部已提交 47'), findsOneWidget);
        expect(find.text('下载打包'), findsNothing);
        final searchRect = tester.getRect(find.byType(AppSearchField));
        final importRect = tester.getRect(
          find.widgetWithText(AppButton, '导入成绩'),
        );
        final packRect = tester.getRect(find.byKey(const ValueKey('ta-pack')));
        expect(packRect.center.dy, searchRect.center.dy);
        expect(importRect.center.dy, searchRect.center.dy);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('ta-roster-toolbar')))
              .height,
          searchRect.height,
        );
        expect(
          importRect.right,
          tester.getRect(find.byKey(const ValueKey('ta-roster-toolbar'))).right,
        );

        expect(searchRect.height, 36.0);
        for (final (control, height) in [
          (find.byKey(const ValueKey('ta-submission-filter')), searchRect.height),
          (find.byTooltip('更新名单和成绩'), searchRect.height),
        ]) {
          final rect = tester.getRect(control);
          expect(rect.height, height);
          expect(rect.center.dy, searchRect.center.dy);
        }
        var visible = 0;
        for (var i = 1; i <= 30; i++) {
          final cell = find.text('示例学生$i');
          if (cell.evaluate().isNotEmpty &&
              tester.getRect(cell).bottom <= 738 &&
              tester.getRect(cell).top >= 0) {
            visible++;
          }
        }
        expect(visible, greaterThanOrEqualTo(8));
        await captureDesktopUi(tester, 'ta-task-table-111-$dark');
        expect(find.text('下载上次打包'), findsNothing);
        await tester.tap(find.byTooltip('下载选项'));
        await tester.pumpAndSettle();
        expect(find.text('下载上次打包'), findsOneWidget);
        expect(find.text('复制下载链接'), findsOneWidget);
        await captureDesktopUi(tester, 'ta-previous-package-menu-$dark');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        final headerY = tester.getTopLeft(find.text('姓名')).dy;
        final firstRowY = tester.getTopLeft(find.text('示例学生1')).dy;
        final selectAll = find.byKey(const ValueKey('ta-select-all'));
        expect(tester.widget<AppCheckbox>(selectAll).value, isFalse);
        await tester.tap(selectAll);
        await tester.pumpAndSettle();
        expect(find.text('已选 111 人'), findsOneWidget);
        expect(
          tester.getRect(find.widgetWithText(AppButton, '导入成绩')),
          importRect,
        );
        expect(tester.getRect(find.byKey(const ValueKey('ta-pack'))), packRect);

        expect(tester.widget<AppCheckbox>(selectAll).value, isTrue);
        expect(tester.getTopLeft(find.text('姓名')).dy, headerY);
        expect(tester.getTopLeft(find.text('示例学生1')).dy, firstRowY);
        await captureDesktopUi(tester, 'ta-stable-select-all-$dark');
        await tester.tap(find.byKey(const ValueKey('ta-select-1')));
        await tester.pumpAndSettle();
        expect(find.text('已选 110 人'), findsOneWidget);
        expect(tester.widget<AppCheckbox>(selectAll).value, isNull);
        expect(tester.getTopLeft(find.text('姓名')).dy, headerY);
        await tester.tap(selectAll);
        await tester.pumpAndSettle();
        expect(find.text('已选 111 人'), findsOneWidget);
        await tester.tap(selectAll);
        await tester.pumpAndSettle();
        expect(tester.widget<AppCheckbox>(selectAll).value, isFalse);
        expect(tester.getTopLeft(find.text('姓名')).dy, headerY);
        await tester.tap(find.byKey(const ValueKey('ta-submission-filter')));
        await tester.pumpAndSettle();
        expect(find.byType(PopupMenuButton<int>), findsNothing);
        expect(find.byType(AppShellSelect<int>), findsOneWidget);
        await captureDesktopUi(tester, 'ta-shared-filter-$dark');
        await tester.tap(find.byKey(const ValueKey('shell-select-option-1')));
        await tester.pumpAndSettle();
        expect(find.text('显示 47 人'), findsOneWidget);
        await tester.tap(selectAll);
        await tester.pumpAndSettle();
        expect(find.text('已选 47 人'), findsOneWidget);
        expect(find.text('打包所选已提交 47'), findsOneWidget);
        await captureDesktopUi(tester, 'ta-task-table-selected-$dark');
        await tester.tap(find.byTooltip('取消选择'));
        await tester.pumpAndSettle();
        expect(find.text('打包全部已提交 47'), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byType(AppSearchField),
            matching: find.byType(TextField),
          ),
          '示例学生47',
        );
        await tester.pumpAndSettle();
        expect(find.text('显示 1 人'), findsOneWidget);
        expect(tester.getRect(find.byType(AppSearchField)), searchRect);
        await tester.tap(find.byTooltip('清空搜索'));
        await tester.pumpAndSettle();
        expect(find.text('显示 47 人'), findsOneWidget);
        expect(tester.getRect(find.byType(AppSearchField)), searchRect);
        await tester.enterText(find.byType(TextField).first, '示例学生47');
        await tester.pumpAndSettle();
        await tester.tap(selectAll);
        await tester.pumpAndSettle();
        expect(find.text('已选 1 人'), findsOneWidget);
        expect(tester.widget<AppCheckbox>(selectAll).value, isTrue);
        expect(find.byTooltip('返回'), findsOneWidget);
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(find.text('修改作业'), findsOneWidget);
        expect(find.text('示例学生47'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets(
    'CSV help is contextual, template uses real newlines and invalidation hides preview',
    (tester) async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          taRepositoryProvider.overrideWith((ref) async {
            ref.onDispose(repo.dispose);
            return repo;
          }),
          currentTeachingCoursesProvider.overrideWith(
            (ref) async => const [CatalogCourse(id: '91', title: '示例课程')],
          ),
          taCsvReaderProvider.overrideWithValue(
            () async => 'user_no,score\n0001,86\n0001,90',
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            home: const Scaffold(body: TaGradingPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(TaHttpFixture.title));
      await tester.pumpAndSettle();
      expect(find.text('复制模板'), findsNothing);
      await tester.tap(find.text('导入成绩'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制模板'));
      await tester.pumpAndSettle();
      expect(copied, 'user_no,score\nDEMO0001,86\nDEMO0002,90\n');
      await tester.tap(find.text('选择 CSV 文件'));
      await tester.pumpAndSettle();
      expect(find.textContaining('错误 2 行'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '提交成绩'))
            .onPressed,
        isNull,
      );
      container.invalidate(taRepositoryProvider);
      await tester.pumpAndSettle();
      expect(find.text('当前页面已失效'), findsOneWidget);
      expect(find.text('示例学生1'), findsNothing);
      expect(f.requests.where((r) => r.method == 'PUT'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  test(
    'TaAssignment.parse and TaAssignmentStore persist optional start_time and end_time safely',
    () async {
      SharedPreferences.setMockInitialValues({});
      const userId = 17;
      final store = TaAssignmentStore(userId);
      final parsed = TaAssignment.parse({
        'id': 81,
        'title': '实验一',
        'expected_submit_count': 12,
        'submitted_count': 8,
        'scored_count': 3,
        'start_time': '2026-09-15T08:00:00Z',
        'end_time': '2026-09-19T15:59:00Z',
        'submit_by_group': false,
        'score_type': 'percentage',
        'rubric_id': 0,
        'data': {'mode': 'normal'},
      });
      expect(parsed.startTime, DateTime.utc(2026, 9, 15, 8));
      expect(parsed.endTime, DateTime.utc(2026, 9, 19, 15, 59));

      final missingTimes = TaAssignment.parse({
        'id': 82,
        'title': '无时间字段作业',
        'submit_by_group': false,
        'score_type': 'percentage',
        'data': {'mode': 'normal'},
      });
      expect(missingTimes.startTime, isNull);
      expect(missingTimes.endTime, isNull);

      final blankTimes = TaAssignment.parse({
        'id': 83,
        'title': '空时间字段作业',
        'start_time': '  ',
        'end_time': null,
        'submit_by_group': false,
        'score_type': 'percentage',
        'data': {'mode': 'normal'},
      });
      expect(blankTimes.startTime, isNull);
      expect(blankTimes.endTime, isNull);

      final checkedAt = DateTime.utc(2026, 9, 16, 10, 30);
      await store.write(
        91,
        TaAssignmentSnapshot([
          parsed,
          TaAssignment(
            id: 84,
            title: '仅截止时间',
            endTime: DateTime.utc(2026, 9, 25, 12),
          ),
          missingTimes,
        ], checkedAt),
      );
      final restored = await store.read(91);
      expect(restored, isNotNull);
      expect(restored!.items, hasLength(3));
      expect(restored.items[0].startTime?.toUtc(), DateTime.utc(2026, 9, 15, 8));
      expect(
        restored.items[0].endTime?.toUtc(),
        DateTime.utc(2026, 9, 19, 15, 59),
      );
      expect(restored.items[1].startTime, isNull);
      expect(restored.items[1].endTime?.toUtc(), DateTime.utc(2026, 9, 25, 12));
      expect(restored.items[2].startTime, isNull);
      expect(restored.items[2].endTime, isNull);

      // Legacy cache entries without start_time/end_time remain readable.
      await JsonDiskCache.writeList('ta_assignments_v1_${userId}_92', [
        {
          'course_id': 92,
          'assignments': [
            {
              'id': 85,
              'title': '旧缓存作业',
              'expected': 10,
              'submitted': 5,
              'graded': 2,
            },
          ],
        },
      ], fetchedAt: checkedAt);
      final legacy = await store.read(92);
      expect(legacy, isNotNull);
      expect(legacy!.items.single.title, '旧缓存作业');
      expect(legacy.items.single.startTime, isNull);
      expect(legacy.items.single.endTime, isNull);
      expect(legacy.items.single.timeMetrics, isEmpty);
    },
  );

  test(
    'TaAssignment.timeMetrics and formatTaAssignmentTime format open/close without middle dots',
    () {
      final sameYearStart = DateTime.utc(2026, 9, 15, 8);
      final sameYearEnd = DateTime.utc(2026, 9, 19, 15, 59);
      final sameYear = TaAssignment(
        id: 1,
        title: '同一年作业',
        startTime: sameYearStart,
        endTime: sameYearEnd,
      );
      final sameCrossYear =
          sameYearStart.toLocal().year != sameYearEnd.toLocal().year;
      expect(sameYear.timeMetrics, [
        (
          '开放',
          formatTaAssignmentTime(sameYearStart, includeYear: sameCrossYear),
        ),
        (
          '截止',
          formatTaAssignmentTime(sameYearEnd, includeYear: sameCrossYear),
        ),
      ]);

      final crossStart = DateTime.utc(2026, 12, 20, 8, 30);
      final crossEnd = DateTime.utc(2027, 1, 5, 14, 15);
      final crossYear = TaAssignment(
        id: 2,
        title: '跨年作业',
        startTime: crossStart,
        endTime: crossEnd,
      );
      expect(crossYear.timeMetrics, [
        ('开放', formatTaAssignmentTime(crossStart, includeYear: true)),
        ('截止', formatTaAssignmentTime(crossEnd, includeYear: true)),
      ]);

      final onlyEnd = TaAssignment(
        id: 3,
        title: '仅截止',
        endTime: sameYearEnd,
      );
      expect(onlyEnd.timeMetrics, [
        ('截止', formatTaAssignmentTime(sameYearEnd)),
      ]);

      for (final item in [sameYear, crossYear, onlyEnd]) {
        for (final metric in item.timeMetrics) {
          final rendered = '${metric.$1} ${metric.$2}';
          expect(rendered, isNot(contains('·')));
          expect(rendered, isNot(contains('•')));
          expect(rendered, isNot(contains('⋅')));
        }
      }
    },
  );

  testWidgets(
    'TaGradingPage and TaAssignmentPage render open and close time text',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1100, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final f = TaHttpFixture();
      final repo = await f.repository();
      addTearDown(repo.dispose);

      final parsed = TaAssignment.parse(f.assignment);
      final expectedOpen =
          '${parsed.timeMetrics[0].$1} ${parsed.timeMetrics[0].$2}';
      final expectedClose =
          '${parsed.timeMetrics[1].$1} ${parsed.timeMetrics[1].$2}';
      expect(
        expectedOpen,
        '开放 ${formatTaAssignmentTime(parsed.startTime!)}',
      );
      expect(
        expectedClose,
        '截止 ${formatTaAssignmentTime(parsed.endTime!)}',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taRepositoryProvider.overrideWith((ref) async => repo),
            currentTeachingCoursesProvider.overrideWith(
              (ref) async => const [CatalogCourse(id: '91', title: '测试课程')],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            home: const Scaffold(body: TaGradingPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TaAssignmentCountChips), findsOneWidget);
      expect(find.byType(TaAssignmentTimeColumn), findsOneWidget);
      expect(find.text(expectedOpen), findsOneWidget);
      expect(find.text(expectedClose), findsOneWidget);

      await tester.tap(find.text(TaHttpFixture.title));
      await tester.pumpAndSettle();

      expect(find.byType(TaAssignmentPage), findsOneWidget);
      expect(find.byType(TaAssignmentSummaryBar), findsOneWidget);
      final openFinder = find.textContaining(expectedOpen);
      final closeFinder = find.textContaining(expectedClose);
      expect(openFinder, findsOneWidget);
      expect(closeFinder, findsOneWidget);
      final subtitleText = tester.widget<Text>(openFinder).data!;
      expect(subtitleText, isNot(contains('·')));
      expect(subtitleText, isNot(contains('•')));
      expect(subtitleText, isNot(contains('⋅')));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      'narrow 320px summary header renders cleanly without wrap or fallback underline ($platform)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final f = TaHttpFixture();
        final repo = await f.repository();
        addTearDown(repo.dispose);

        final parsed = TaAssignment.parse(f.assignment);
        final expectedOpen =
            '${parsed.timeMetrics[0].$1} ${parsed.timeMetrics[0].$2}';
        final expectedClose =
            '${parsed.timeMetrics[1].$1} ${parsed.timeMetrics[1].$2}';

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taRepositoryProvider.overrideWith((ref) async => repo),
              currentTeachingCoursesProvider.overrideWith(
                (ref) async => const [CatalogCourse(id: '91', title: '测试课程')],
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light().copyWith(platform: platform),
              home: const Scaffold(body: TaGradingPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(TaHttpFixture.title));
        await tester.pumpAndSettle();

        if (platform == TargetPlatform.android) {
          expect(find.byType(TaMobileAssignmentPage), findsOneWidget);
          final rows = tester
              .widgetList<TaStudentRow>(find.byType(TaStudentRow))
              .toList();
          expect(rows, hasLength(3));
          expect(rows.first.isFirst, isTrue);
          expect(rows.first.isLast, isFalse);
          expect(rows[1].isFirst, isFalse);
          expect(rows[1].isLast, isFalse);
          expect(rows.last.isFirst, isFalse);
          expect(rows.last.isLast, isTrue);
        } else {
          expect(find.byType(TaAssignmentPage), findsOneWidget);
        }

        expect(find.byType(TaAssignmentSummaryBar), findsOneWidget);
        for (final chip in [
          '应交 ${parsed.expected}',
          '已提交 ${parsed.submitted}',
          '已批改 ${parsed.graded}',
        ]) {
          final finder = find.text(chip);
          expect(finder, findsOneWidget);
          final ctx = tester.element(finder);
          expect(
            DefaultTextStyle.of(ctx).style.decoration,
            isNot(TextDecoration.underline),
          );
        }

        for (final timeText in [expectedOpen, expectedClose]) {
          final finder = find.text(timeText);
          expect(finder, findsOneWidget);
          final ctx = tester.element(finder);
          expect(
            DefaultTextStyle.of(ctx).style.decoration,
            isNot(TextDecoration.underline),
          );
          final paragraph = ctx.renderObject! as RenderParagraph;
          expect(paragraph.didExceedMaxLines, isFalse, reason: timeText);
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
          )..layout();
          expect(
            paragraph.size.width,
            greaterThanOrEqualTo(painter.width - 0.5),
            reason: timeText,
          );
          expect(
            paragraph.size.height,
            lessThanOrEqualTo(painter.height + 1.0),
            reason: timeText,
          );
          painter.dispose();
        }

        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
