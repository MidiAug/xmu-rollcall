import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_overview.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_repository.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
  void clear() => state = const AuthState(status: AuthStatus.signedOut);
}

class _Repo extends Fake implements HomeworkRepository {
  final courses = <int>[];
  int statusCalls = 0;
  CancelToken? statusToken;
  bool fail = false;
  Future<void> Function()? duringCourse;
  Future<void> Function()? duringStatus;
  @override
  Future<HomeworkTodosFetch> fetchTodosDetailed() async =>
      const HomeworkTodosFetch(items: [], diag: {});
  @override
  Future<List<HomeworkItem>> fetchCourseHomework(int id) async {
    courses.add(id);
    await duringCourse?.call();
    if (fail) throw StateError('offline');
    return [
      HomeworkItem(
        id: id * 10,
        title: 'Task $id',
        courseId: id,
        dueAt: DateTime.now().add(Duration(days: id == 1 ? 1 : -1)),
      ),
    ];
  }

  @override
  Future<HomeworkSubmissionState> fetchSubmission({
    required int activityId,
    required int studentId,
    CancelToken? cancelToken,
  }) async {
    statusCalls++;
    statusToken = cancelToken;
    await Future.any<void>([
      duringStatus?.call() ?? Future<void>.value(),
      if (cancelToken != null)
        cancelToken.whenCancel.then<void>((error) => throw error),
    ]);
    if (fail) throw StateError('offline');
    return const HomeworkSubmissionState(
      submission: HomeworkSubmission.submitted,
      grading: HomeworkGrading.pending,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Repo repo;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = _Repo();
    await CourseCatalogStore.write(
      1,
      CourseCatalogSnapshot(
        fetchedAt: DateTime.now(),
        rolesResolved: true,
        courses: [
          for (final id in [1, 2, 3])
            CatalogCourse(
              id: '$id',
              title: 'Course $id',
              roles: id == 3 ? ['instructor_assistant'] : ['student'],
              timetables: {
                1: [
                  TimetableSlot(
                    sequence: 1,
                    start: DateTime(2000, 1, 3, 8),
                    end: DateTime(2000, 1, 3, 9),
                  ),
                ],
              },
            ),
          const CatalogCourse(id: '4', title: 'Historical course'),
        ],
      ),
    );
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => _Auth()),
        homeworkRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });
  tearDown(() => container.dispose());
  test(
    'warm overview survives tab switches and failures keep their cooldown',
    () async {
      var sub = container.listen(homeworkOverviewProvider, (_, _) {});
      await container.read(homeworkOverviewProvider.future);
      final notifier = container.read(homeworkOverviewProvider.notifier);
      await notifier.ensureFresh();
      final cached = container.read(homeworkOverviewProvider).requireValue;
      for (var i = 0; i < 5; i++) {
        sub.close();
        await container.pump();
        sub = container.listen(homeworkOverviewProvider, (_, _) {});
        expect(container.read(homeworkOverviewProvider).isLoading, isFalse);
        expect(
          container.read(homeworkOverviewProvider).requireValue,
          same(cached),
        );
        await notifier.ensureFresh();
      }
      expect(repo.courses, [1, 2]);
      repo.fail = true;
      await notifier.ensureFresh(force: true);
      final afterFailure = repo.courses.length;
      sub.close();
      await container.pump();
      sub = container.listen(homeworkOverviewProvider, (_, _) {});
      await notifier.ensureFresh();
      expect(repo.courses.length, afterFailure);
      expect(
        container.read(homeworkOverviewProvider).requireValue.items,
        hasLength(2),
      );
      sub.close();
    },
  );
  test(
    'leaving during a scan stops later courses and can resume on return',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      repo.duringCourse = () {
        if (!entered.isCompleted) entered.complete();
        return release.future;
      };
      final sub = container.listen(homeworkOverviewProvider, (_, _) {});
      await container.read(homeworkOverviewProvider.future);
      final notifier = container.read(homeworkOverviewProvider.notifier);
      final work = notifier.ensureFresh();
      await entered.future;
      sub.close();
      await container.pump();
      release.complete();
      await work;
      expect(repo.courses, [1]);
      expect(await JsonDiskCache.readList('course_homework_1_1'), isNull);
      final resumed = container.listen(homeworkOverviewProvider, (_, _) {});
      addTearDown(resumed.close);
      await notifier.ensureFresh();
      expect(repo.courses, [1, 1, 2]);
      expect(
        container.read(homeworkOverviewProvider).requireValue.items,
        hasLength(2),
      );
    },
  );
  test(
    'late course response after logout cannot write old account mirrors or query the next course',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      repo.duringCourse = () {
        if (!entered.isCompleted) entered.complete();
        return release.future;
      };
      final sub = container.listen(homeworkOverviewProvider, (_, _) {});
      addTearDown(sub.close);
      final pending = container
          .read(homeworkOverviewProvider.future)
          .then<void>((_) {}, onError: (Object error, StackTrace stack) {});
      await entered.future;
      final refreshing = container
          .read(homeworkOverviewProvider.notifier)
          .ensureFresh();
      (container.read(authControllerProvider.notifier) as _Auth).clear();
      expect(
        (await container.read(homeworkOverviewProvider.future)).items,
        isEmpty,
      );
      release.complete();
      await pending;
      await refreshing;
      expect(await JsonDiskCache.readList('course_homework_1_1'), isNull);
      expect(repo.courses, [1]);
    },
  );
  test(
    'overview scans only current student courses, reuses disk and keeps old lists after failure',
    () async {
      final sub = container.listen(homeworkOverviewProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(homeworkOverviewProvider.future);
      await container.read(homeworkOverviewProvider.notifier).ensureFresh();
      final first = container.read(homeworkOverviewProvider).requireValue;
      expect(first.items.map((i) => i.courseId), [2, 1]);
      expect(repo.courses, [1, 2]);
      await container.read(homeworkOverviewProvider.notifier).ensureFresh();
      expect(repo.courses, [1, 2]);
      container.invalidate(homeworkOverviewProvider);
      await container.read(homeworkOverviewProvider.future);
      expect(repo.courses, [1, 2]);
      repo.fail = true;
      for (final cid in [1, 2]) {
        final suffix = 'course_homework_1_$cid';
        final disk = (await JsonDiskCache.readList(suffix))!;
        await JsonDiskCache.writeList(
          suffix,
          disk.items,
          fetchedAt: DateTime.now().subtract(const Duration(days: 8)),
        );
      }
      await container
          .read(homeworkOverviewProvider.notifier)
          .ensureFresh(force: true);
      expect(
        container.read(homeworkOverviewProvider).requireValue.items,
        hasLength(2),
      );
      expect(
        container.read(homeworkOverviewProvider).requireValue.failedCourses,
        2,
      );
      expect(
        (await JsonDiskCache.readList(
          'course_homework_1_1',
        ))!.items.single['title'],
        'Task 1',
      );
    },
  );
  testWidgets('a slow cold submission stops loading after its deadline', (
    tester,
  ) async {
    repo.duringStatus = () => Completer<void>().future;
    final provider = homeworkSubmissionProvider(const HomeworkStatusKey(1, 98));
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    final checked = expectLater(
      container.read(provider.future),
      throwsA(isA<DioException>()),
    );
    await tester.pumpAndSettle();
    expect(repo.statusCalls, 1);
    expect(container.read(provider).isLoading, isTrue);
    await tester.pump(const Duration(seconds: 31));
    await checked;
    expect(repo.statusToken?.isCancelled, isTrue);
    expect(container.read(provider).isLoading, isFalse);
    expect(container.read(provider).hasError, isTrue);
  });

  test(
    'leaving a cold status row cancels the queued or active request',
    () async {
      final entered = Completer<void>();
      final hold = Completer<void>();
      repo.duringStatus = () {
        entered.complete();
        return hold.future;
      };
      final provider = homeworkSubmissionProvider(
        const HomeworkStatusKey(1, 99),
      );
      final sub = container.listen(provider, (_, _) {});
      final pending = expectLater(
        container.read(provider.future),
        throwsA(isA<DioException>()),
      );
      await entered.future;
      sub.close();
      await container.pump();
      expect(repo.statusToken?.isCancelled, isTrue);
      await pending;
      expect(await JsonDiskCache.readList('homework_submission_1_99'), isNull);
    },
  );

  test(
    'manual overview refresh does not rescan unchanged warm courses',
    () async {
      final sub = container.listen(homeworkOverviewProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(homeworkOverviewProvider.future);
      final notifier = container.read(homeworkOverviewProvider.notifier);
      await notifier.ensureFresh();
      expect(repo.courses, [1, 2]);
      await notifier.ensureFresh(force: true);
      expect(repo.courses, [1, 2]);
    },
  );

  test(
    'cold status restores stale cache while a slow request is pending',
    () async {
      const key = HomeworkStatusKey(1, 10);
      const cached = HomeworkSubmissionState(
        submission: HomeworkSubmission.unsubmitted,
        grading: HomeworkGrading.unknown,
      );
      await JsonDiskCache.writeList(
        'homework_submission_1_10',
        [cached.toJson()],
        fetchedAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      repo.duringStatus = () {
        entered.complete();
        return release.future;
      };
      final updated = Completer<void>();
      final provider = homeworkSubmissionProvider(key);
      final sub = container.listen(provider, (_, value) {
        if (value.valueOrNull?.submission == HomeworkSubmission.submitted &&
            !updated.isCompleted) {
          updated.complete();
        }
      });
      addTearDown(sub.close);
      expect(
        (await container.read(provider.future)).submission,
        HomeworkSubmission.unsubmitted,
      );
      await entered.future;
      expect(container.read(provider).isLoading, isFalse);
      expect(
        container.read(provider).requireValue.submission,
        HomeworkSubmission.unsubmitted,
      );
      release.complete();
      await updated.future;
      expect(
        container.read(provider).requireValue.submission,
        HomeworkSubmission.submitted,
      );
    },
  );

  test(
    'personal status cache honors manual refresh, failures and published-grade TTL',
    () async {
      const key = HomeworkStatusKey(1, 10);
      final provider = homeworkSubmissionProvider(key);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.future);
      expect(repo.statusCalls, 1);
      container.invalidate(provider);
      await container.read(provider.future);
      expect(repo.statusCalls, 1);
      repo.fail = true;
      container.read(homeworkManualRefreshAtProvider(1).notifier).state =
          DateTime.now();
      expect(
        (await container.read(provider.future)).submission,
        HomeworkSubmission.submitted,
      );
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(repo.statusCalls, 2);
      container.read(homeworkManualRefreshAtProvider(1).notifier).state = null;
      await JsonDiskCache.writeList(
        'homework_submission_1_10',
        [
          const HomeworkSubmissionState(
            submission: HomeworkSubmission.submitted,
            grading: HomeworkGrading.graded,
            score: 0,
          ).toJson(),
        ],
        fetchedAt: DateTime.now().subtract(const Duration(hours: 6)),
      );
      container.invalidate(provider);
      expect((await container.read(provider.future)).score, 0);
      expect(repo.statusCalls, 2);
      repo.fail = false;
      final deadlineKey = HomeworkStatusKey(
        1,
        10,
        closed: true,
        dueAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      final deadlineProvider = homeworkSubmissionProvider(deadlineKey);
      final deadlineSub = container.listen(deadlineProvider, (_, _) {});
      addTearDown(deadlineSub.close);
      await container.read(deadlineProvider.future);
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(
        repo.statusCalls,
        3,
        reason: 'crossing a deadline bypasses an otherwise fresh cache once',
      );
      container.invalidate(deadlineProvider);
      await container.read(deadlineProvider.future);
      await Future<void>.delayed(Duration.zero);
      await container.pump();
      expect(repo.statusCalls, 3);
    },
  );
}
