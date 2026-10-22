import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/homework/homework_hub_page.dart';
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

void main() {
  for (final width in [320.0, 384.0, 960.0]) {
    testWidgets(
      'compact aligned homework rows fit $width and details still link all four',
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
            child: const MaterialApp(home: Scaffold(body: HomeworkHubPage())),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('助教作业4'), findsOneWidget);
        expect(find.text('助教课程示例'), findsOneWidget);
        expect(find.text('进行中 1 项'), findsNothing);
        expect(find.text('已截止 3 项'), findsNothing);
        expect(find.text('查看全部 4 项作业'), findsNothing);
        expect(find.text('助教作业1'), findsNothing);
        expect(find.text('我需提交的作业'), findsOneWidget);
        expect(find.text('未提交'), findsOneWidget);
        expect(find.text('已提交'), findsNWidgets(2));
        expect(find.text('已批改 0 分'), findsOneWidget);
        expect(find.text('已截止  2'), findsOneWidget);
        expect(find.text('成绩未公布'), findsOneWidget);
        final deadline9 = find.byKey(const ValueKey('homework-deadline-9'));
        final deadline10 = find.byKey(const ValueKey('homework-deadline-10'));
        final submission9 = find.byKey(const ValueKey('homework-submission-9'));
        final submission10 = find.byKey(
          const ValueKey('homework-submission-10'),
        );
        expect(
          tester.getSize(deadline9).width,
          tester.getSize(deadline10).width,
        );
        expect(
          tester.getTopLeft(submission9).dx,
          tester.getTopLeft(submission10).dx,
        );
        expect(
          tester.getSize(submission9).width,
          tester.getSize(submission10).width,
        );
        expect(find.text('01/02 03:04'), findsOneWidget);
        expect(
          tester.getTopLeft(submission9).dx - tester.getTopRight(deadline9).dx,
          6,
        );
        final grading9 = find.byKey(const ValueKey('homework-grading-9'));
        final grading10 = find.byKey(const ValueKey('homework-grading-10'));
        expect(tester.getTopLeft(grading9).dx, tester.getTopLeft(grading10).dx);
        expect(
          tester.getTopLeft(grading9).dx - tester.getTopRight(submission9).dx,
          6,
        );
        final title = tester.widget<Text>(find.textContaining('已批改的历史作业标题'));
        expect(title.maxLines, 1);
        expect(title.overflow, TextOverflow.ellipsis);
        await tester.tap(find.text('助教作业4'));
        await tester.pumpAndSettle();
        expect(find.byType(HomeworkDetailPage), findsOneWidget);
        await tester.tap(find.text('查看该课全部'));
        await tester.pumpAndSettle();
        for (var i = 1; i <= 4; i++) {
          expect(find.text('助教作业$i'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
