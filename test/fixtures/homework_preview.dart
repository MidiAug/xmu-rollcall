import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_overview.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';

class _AuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Authentication is disabled in the preview.');
}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepository()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '林同学'),
    );
  }
}

final _homework = [
  HomeworkItem(
    id: 1,
    courseId: 7,
    title: '实验二：分类模型与评估',
    courseName: '机器学习',
    dueAt: DateTime(2026, 11, 25, 23, 59),
  ),
  HomeworkItem(
    id: 2,
    courseId: 8,
    title: '软件需求分析报告',
    courseName: '软件工程',
    dueAt: DateTime(2026, 11, 27, 23, 59),
  ),
  HomeworkItem(
    id: 3,
    courseId: 7,
    title: '实验一：数据预处理',
    courseName: '机器学习',
    closed: true,
    dueAt: DateTime(2026, 11, 20, 23, 59),
  ),
];

class _Todos extends HomeworkTodosNotifier {
  @override
  Future<List<HomeworkItem>> build() async => _homework;
}

class _Overview extends HomeworkOverviewNotifier {
  @override
  Future<HomeworkOverview> build() async => HomeworkOverview(_homework);

  @override
  Future<bool> ensureFresh({bool force = false}) async => true;
}

/// Real homework widgets with deterministic, in-memory demo data.
class HomeworkPreviewScope extends StatelessWidget {
  const HomeworkPreviewScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(SecureStore.memory()),
      authControllerProvider.overrideWith((ref) => _Auth()),
      assistControllerProvider.overrideWith(
        (ref) => AssistController(ref, bootstrap: false),
      ),
      homeworkClockProvider.overrideWithValue(() => DateTime(2026, 11, 24, 10)),
      homeworkTodosProvider.overrideWith(_Todos.new),
      homeworkOverviewProvider.overrideWith(_Overview.new),
      currentTeachingCoursesProvider.overrideWith((ref) async => const []),
      homeworkSubmissionProvider.overrideWith(
        (ref, item) async => HomeworkSubmissionState(
          submission: item.activityId == 1
              ? HomeworkSubmission.unsubmitted
              : HomeworkSubmission.submitted,
          grading: item.activityId == 3
              ? HomeworkGrading.graded
              : HomeworkGrading.pending,
          score: item.activityId == 3 ? 92 : null,
        ),
      ),
    ],
    child: child,
  );
}
