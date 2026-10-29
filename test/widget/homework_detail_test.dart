import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/homework/homework_course_page.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_overview.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

void main() {
  testWidgets('detail to course to another detail preserves course context', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const seed = HomeworkItem(
      id: 7,
      title: 'Essay',
      courseId: 3,
      courseName: 'English',
    );
    const next = HomeworkItem(id: 8, title: 'Next essay');
    await JsonDiskCache.writeList('course_homework_1_3', [next.toJson()]);
    await JsonDiskCache.writeList('homework_todos_1', []);
    final opened = <HomeworkDetailKey>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          currentTeachingCoursesProvider.overrideWith((ref) async => const []),
          homeworkSubmissionProvider.overrideWith(
            (ref, key) async => const HomeworkSubmissionState(
              submission: HomeworkSubmission.unknown,
            ),
          ),
          homeworkDetailProvider.overrideWith((ref, key) async {
            opened.add(key);
            return key.seed!;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const HomeworkDetailPage(seed: seed),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看该课全部'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeworkCoursePage), findsOneWidget);
    await tester.tap(find.text('Next essay'));
    await tester.pumpAndSettle();
    expect(opened.last.activityId, 8);
    expect(opened.last.seed!.courseId, 3);
    expect(opened.last.seed!.courseName, 'English');
    expect(find.text('Next essay'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeworkCoursePage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [320.0, 960.0]) {
    testWidgets('submission chips follow all detail fields at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const seed = HomeworkItem(
        id: 7,
        title: 'Essay',
        courseId: 3,
        courseName: 'English',
        type: 'homework',
        status: 'open',
        description: 'Assignment instructions',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _Auth()),
            currentTeachingCoursesProvider.overrideWith(
              (ref) async => const [],
            ),
            homeworkDetailProvider.overrideWith((ref, key) async => seed),
            homeworkSubmissionProvider.overrideWith(
              (ref, key) async => const HomeworkSubmissionState(
                submission: HomeworkSubmission.submitted,
                grading: HomeworkGrading.graded,
              ),
            ),
          ],
          child: MaterialApp(
            theme: width < 600 ? AppTheme.dark() : AppTheme.light(),
            home: const HomeworkDetailPage(seed: seed),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('已提交'), findsOneWidget);
      expect(find.text('已批改'), findsOneWidget);
      final bottom = tester
          .getBottomLeft(find.text('Assignment instructions'))
          .dy;
      expect(tester.getTopLeft(find.text('已提交')).dy, greaterThan(bottom));
      expect(tester.getTopLeft(find.text('已批改')).dy, greaterThan(bottom));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('detail shows 查看该课全部 when courseId present', (tester) async {
    final seed = HomeworkItem(
      id: 7,
      title: 'Essay',
      courseId: 3,
      courseName: 'English',
      dueAt: DateTime.utc(2026, 10, 1),
      status: 'open',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeworkDetailProvider.overrideWith((ref, key) async => seed),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: HomeworkDetailPage(seed: seed),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('查看该课全部'), findsOneWidget);
    expect(find.text('Essay'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('detail hides 查看该课全部 without courseId', (tester) async {
    final seed = const HomeworkItem(id: 8, title: 'No course');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeworkDetailProvider.overrideWith((ref, key) async => seed),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: HomeworkDetailPage(seed: seed),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('查看该课全部'), findsNothing);
    expect(find.textContaining('缺少课程 id'), findsOneWidget);
  });
}
