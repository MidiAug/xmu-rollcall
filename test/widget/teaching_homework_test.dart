import 'package:xmu_rollcall/core/theme/app_icons.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import '../fixtures/preview_fonts.dart';
import '../fixtures/desktop_ui_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/homework/homework_course_page.dart';
import 'package:xmu_rollcall/features/homework/homework_hub_page.dart';
import 'package:xmu_rollcall/features/homework/homework_list_row.dart';
import 'package:xmu_rollcall/features/homework/homework_overview.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

final assignments = [
  for (var i = 1; i <= 4; i++)
    HomeworkItem(
      id: i,
      title: '助教作业$i',
      courseId: 9,
      dueAt: DateTime.now().add(Duration(days: i == 4 ? 7 : -7)),
    ),
];

class _Todos extends HomeworkTodosNotifier {
  @override
  Future<List<HomeworkItem>> build() async => [
    ...assignments.take(3),
    const HomeworkItem(id: 8, title: '我需提交的作业', courseId: 2),
  ];
}

class _Course extends CourseHomeworkNotifier {
  @override
  Future<List<HomeworkItem>> build(int id) async => assignments;
  @override
  Future<void> ensureFresh({
    EnsureFreshReason reason = EnsureFreshReason.appear,
  }) async {}
}

class _EmptyCourse extends _Course {
  @override
  Future<List<HomeworkItem>> build(int id) async => const [];
}

class _Overview extends HomeworkOverviewNotifier {
  @override
  Future<HomeworkOverview> build() async => HomeworkOverview([
    HomeworkItem(id: 8, title: '我需提交的作业', courseId: 2),
    HomeworkItem(
      id: 9,
      title: '已批改的历史作业标题很长时也应该只显示一行并且省略后面的内容',
      courseId: 2,
      dueAt: DateTime(DateTime.now().year - 1, 1, 2, 3, 4),
    ),
    HomeworkItem(
      id: 10,
      title: '尚未公布成绩的作业',
      courseId: 2,
      dueAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ]);
}

class _LongOverview extends HomeworkOverviewNotifier {
  @override
  Future<HomeworkOverview> build() async => HomeworkOverview([
    for (var i = 0; i < 80; i++)
      HomeworkItem(
        id: 100 + i,
        title: '${i < 40 ? '进行中' : '已截止'}作业 $i',
        courseName: '示例课程',
        courseId: 2,
        closed: i >= 40,
      ),
  ]);
}

void main() {
  initializeDesktopUiCapture();
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  for (final (width, scale) in [(384.0, 1.5), (960.0, 1.0)]) {
    testWidgets(
      'empty teaching courses stay compact and long names remain readable at $width',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const courseTitle =
            '复杂软件系统的分析、设计与验证：分布式架构、并发程序分析、形式化验证、'
            '数据密集型应用、人工智能系统可靠性与跨学科工程实践联合专题研究（研究生课程）';
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith((ref) => _Auth()),
              assistControllerProvider.overrideWith(
                (ref) => AssistController(
                  ref,
                  bootstrap: false,
                  initial: const AssistUiState(ready: true),
                ),
              ),
              homeworkTodosProvider.overrideWith(_Todos.new),
              homeworkOverviewProvider.overrideWith(_Overview.new),
              homeworkSubmissionProvider.overrideWith(
                (ref, key) async => const HomeworkSubmissionState(
                  submission: HomeworkSubmission.unsubmitted,
                ),
              ),
              courseHomeworkProvider.overrideWith(_EmptyCourse.new),
              currentTeachingCoursesProvider.overrideWith(
                (ref) async => const [
                  CatalogCourse(
                    id: '9',
                    title: courseTitle,
                    roles: ['instructor_assistant'],
                  ),
                ],
              ),
            ],
            child: RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                theme: AppTheme.light().copyWith(
                  platform: width < 600
                      ? TargetPlatform.android
                      : TargetPlatform.windows,
                ),
                home: const Scaffold(body: HomeworkHubPage()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final emptyStatus = find.text('暂无进行中作业');
        expect(emptyStatus, findsOneWidget);
        expect(find.text('助教课程'), findsOneWidget);
        expect(
          find.ancestor(
            of: emptyStatus,
            matching: find.byType(SettingsSection),
          ),
          findsNothing,
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('teaching-empty-9'))).height,
          lessThan(90 * scale),
        );
        expect(find.text('我需提交的作业'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await captureDesktopUi(
          tester,
          'homework-empty-teaching-${width.toInt()}-scale$scale',
        );
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(courseTitle))
              .didExceedMaxLines,
          isTrue,
          reason:
              'This fixture must actually truncate before expecting a full-name tooltip',
        );
        await tester.longPress(find.text(courseTitle));
        await tester.pumpAndSettle();
        expect(find.text(courseTitle), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('truncated assignment names reveal the full title after hover', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(440, 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const title = '软件工程导论实验报告：需求分析、接口设计与完整验证记录';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeworkListRow(
            item: const HomeworkItem(id: 1, title: title),
            subtitle: '',
            trailing: const Text('11/12 23:59'),
            onTap: () {},
          ),
        ),
      ),
    );
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    await pointer.moveTo(tester.getCenter(find.text(title)));
    await tester.pump(const Duration(milliseconds: 499));
    expect(find.text(title), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(title), findsNWidgets(2));
    await pointer.moveTo(const Offset(430, 290));
    await tester.pumpAndSettle();
    expect(find.text(title), findsOneWidget);
    await pointer.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'changing a deep result filter starts at the top; detail returns in place',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(960, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _Auth()),
            assistControllerProvider.overrideWith(
              (ref) => AssistController(
                ref,
                bootstrap: false,
                initial: const AssistUiState(ready: true),
              ),
            ),
            homeworkTodosProvider.overrideWith(_Todos.new),
            homeworkOverviewProvider.overrideWith(_LongOverview.new),
            currentTeachingCoursesProvider.overrideWith((ref) async => []),
            homeworkSubmissionProvider.overrideWith(
              (ref, key) async => const HomeworkSubmissionState(
                submission: HomeworkSubmission.unsubmitted,
              ),
            ),
            homeworkDetailProvider.overrideWith((ref, key) async => key.seed!),
          ],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: child!,
            ),
            home: const Scaffold(body: HomeworkHubPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final position = Scrollable.of(
        tester.element(find.byType(HomeworkListRow).first),
      ).position;
      position.jumpTo(position.maxScrollExtent - 100);
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(1000));
      await captureDesktopUi(tester, 'homework-deep-before-filter');
      final ongoingFilter = find.text('进行中 40');
      expect(ongoingFilter.hitTestable(), findsOneWidget);
      await tester.tap(ongoingFilter);
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      expect(find.text('进行中作业 0').hitTestable(), findsOneWidget);
      expect(find.text('已截止作业 79'), findsNothing);
      await captureDesktopUi(tester, 'homework-filter-first-result');

      position.jumpTo(400);
      await tester.pumpAndSettle();
      final target = find.text('进行中作业 7');
      await tester.ensureVisible(target);
      final beforeDetail = position.pixels;
      expect(beforeDetail, greaterThan(0));
      await tester.tap(target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await captureDesktopUi(tester, 'homework-detail-entering');
      await tester.pumpAndSettle();
      expect(find.byType(HomeworkDetailPage), findsOneWidget);
      await captureDesktopUi(tester, 'homework-detail-ready');
      await tester.tap(find.byTooltip('返回'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      await captureDesktopUi(tester, 'homework-detail-returning');
      await tester.pumpAndSettle();
      expect(position.pixels, beforeDetail);
      expect(target.hitTestable(), findsOneWidget);
      await captureDesktopUi(tester, 'homework-detail-restored-position');
      expect(tester.takeException(), isNull);
    },
  );

  for (final (width, scale, dark) in const [
    (320.0, 1.0, false),
    (384.0, 1.0, false),
    (960.0, 1.0, false),
    (960.0, 1.5, false),
    (960.0, 2.0, true),
    (320.0, 1.5, false),
    (760.0, 1.0, false),
    (1920.0, 1.0, false),
    (760.0, 1.0, true),
    (1920.0, 1.0, true),
  ]) {
    testWidgets(
      'compact aligned homework rows fit $width scale=$scale dark=$dark and details still link all four',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith((ref) => _Auth()),
              assistControllerProvider.overrideWith(
                (ref) => AssistController(
                  ref,
                  bootstrap: false,
                  initial: const AssistUiState(ready: true),
                ),
              ),
              homeworkTodosProvider.overrideWith(_Todos.new),
              homeworkOverviewProvider.overrideWith(_Overview.new),
              homeworkSubmissionProvider.overrideWith(
                (ref, key) async => key.activityId == 9
                    ? const HomeworkSubmissionState(
                        submission: HomeworkSubmission.submitted,
                        grading: HomeworkGrading.graded,
                        score: 0,
                      )
                    : key.activityId == 10
                    ? const HomeworkSubmissionState(
                        submission: HomeworkSubmission.submitted,
                        grading: HomeworkGrading.unpublished,
                      )
                    : const HomeworkSubmissionState(
                        submission: HomeworkSubmission.unsubmitted,
                      ),
              ),
              homeworkDetailProvider.overrideWith(
                (ref, key) async => key.seed!,
              ),
              courseHomeworkProvider.overrideWith(_Course.new),
              currentTeachingCoursesProvider.overrideWith(
                (ref) async => const [
                  CatalogCourse(
                    id: '9',
                    title: '助教课程示例',
                    roles: ['instructor_assistant'],
                  ),
                ],
              ),
            ],
            child: RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: width < 600
                      ? TargetPlatform.android
                      : TargetPlatform.windows,
                ),
                home: const Scaffold(body: HomeworkHubPage()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('助教作业4'), findsOneWidget);
        if (width < 600) {
          expect(find.byKey(const ValueKey('homework-refresh')), findsNothing);
          expect(find.byIcon(AppIcons.person), findsNothing);
        }
        final teachingRow = find.ancestor(
          of: find.text('助教作业4'),
          matching: find.byType(AppHoverSurface),
        );
        final teachingPanel = find.ancestor(
          of: teachingRow,
          matching: find.byType(SettingsSection),
        );
        expect(
          tester.getRect(teachingRow).left,
          tester.getRect(teachingPanel).left,
        );
        expect(
          tester.getRect(teachingRow).right,
          tester.getRect(teachingPanel).right,
        );
        expect(find.text('助教课程示例'), findsOneWidget);
        expect(find.text('进行中 1 项'), findsNothing);
        expect(find.text('已截止 3 项'), findsNothing);
        expect(find.text('查看全部 4 项作业'), findsNothing);
        expect(find.text('助教作业1'), findsNothing);
        expect(find.text('我需提交的作业'), findsOneWidget);
        expect(find.text('未提交'), findsOneWidget);
        expect(find.text('已提交'), findsNothing);
        expect(find.text('0 分'), findsOneWidget);
        expect(find.textContaining(RegExp(r'^已截止\s*2$')), findsNWidgets(2));
        expect(find.text('成绩未公布'), findsOneWidget);
        // Finding a Text is insufficient: clipped labels remain in the tree.
        for (final label in ['未提交', '成绩未公布', '0 分']) {
          for (final element in find.text(label).evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            expect(paragraph.didExceedMaxLines, isFalse, reason: label);
            final painter = TextPainter(
              text: paragraph.text,
              textDirection: paragraph.textDirection,
              textScaler: paragraph.textScaler,
            )..layout();
            expect(
              paragraph.size.width,
              greaterThanOrEqualTo(painter.width),
              reason: label,
            );
            painter.dispose();
          }
        }
        final zero = find.text('0 分');
        final unpublished = find.text('成绩未公布');
        expect(zero, findsOneWidget);
        expect(unpublished, findsOneWidget);
        expect(
          find.ancestor(of: zero, matching: find.byType(FittedBox)),
          findsNothing,
        );
        final title = tester.widget<Text>(find.textContaining('已批改的历史作业标题'));
        expect(title.maxLines, 1);
        expect(title.overflow, TextOverflow.ellipsis);
        if (width >= 600) {
          final filters = find.byWidgetPredicate(
            (w) => w is AppSegmentedControl,
          );
          expect(
            tester.getRect(filters).left,
            tester.getRect(teachingPanel).left,
          );
          expect(
            tester.getRect(find.byType(AppRefreshButton).first).right,
            tester.getRect(teachingPanel).right,
          );
          final filter = find.text('全部 3');
          expect(filter, findsOneWidget);
          expect(
            (tester.getCenter(filter).dy -
                    tester.getCenter(find.byType(AppRefreshButton).first).dy)
                .abs(),
            lessThan(4),
          );
          expect(
            tester.getTopRight(filter).dx,
            lessThan(tester.getTopLeft(find.byType(AppRefreshButton).first).dx),
          );
          await tester.tap(find.text('进行中 1'));
          await tester.pumpAndSettle();
          expect(find.text('我需提交的作业'), findsOneWidget);
          expect(find.text('尚未公布成绩的作业'), findsNothing);
          await tester.tap(find.text('已截止 2').first);
          await tester.pumpAndSettle();
          expect(find.text('我需提交的作业'), findsNothing);
          expect(find.text('尚未公布成绩的作业'), findsOneWidget);
          await tester.tap(filter);
          await tester.pumpAndSettle();
        }

        await captureDesktopUi(
          tester,
          'homework-hub-${width.toInt()}${dark ? '-dark' : ''}${scale == 1 ? '' : '-scale$scale'}',
        );
        await tester.tap(find.text('助教作业4'));
        await tester.pumpAndSettle();
        expect(find.byType(HomeworkDetailPage), findsOneWidget);
        await tester.tap(find.text('课程作业'));
        await tester.pumpAndSettle();
        for (var i = 1; i <= 4; i++) {
          expect(find.text('助教作业$i'), findsOneWidget);
        }
        final filter = find.byKey(const ValueKey('homework-course-filter'));
        expect(filter, findsOneWidget);
        await tester.tap(find.text('进行中 1').last);
        await tester.pumpAndSettle();
        expect(find.text('助教作业1'), findsNothing);
        expect(find.text('助教作业4'), findsOneWidget);
        await tester.tap(find.text('全部 4'));
        await tester.pumpAndSettle();
        final courseRows = tester
            .widgetList<HomeworkListRow>(
              find.descendant(
                of: find.byType(HomeworkCoursePage),
                matching: find.byType(HomeworkListRow),
              ),
            )
            .toList();
        expect(courseRows, hasLength(4));
        for (final row in courseRows) {
          expect(row.subtitle, isEmpty);
        }
        await captureDesktopUi(
          tester,
          'homework-course-menu-${width.toInt()}${scale == 1 ? '' : '-scale$scale'}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
