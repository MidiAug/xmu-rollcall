import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/core/cache/history_candidates.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

class _Repository extends Fake implements RollcallRepository {
  final calls = <String>[];
  bool fail = false;
  Future<void> Function()? duringFetch;

  @override
  Future<List<CourseRollcallRecord>> fetchCourseRollcalls({
    required Object courseId,
    required int studentId,
    String courseTitle = '',
  }) async {
    calls.add('$courseId');
    await duringFetch?.call();
    if (fail) throw StateError('offline');
    return const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repo;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = _Repository();
    await CourseCatalogStore.write(
      1,
      CourseCatalogSnapshot(
        fetchedAt: DateTime.now(),
        rolesResolved: true,
        courses: [
          for (final id in ['a', 'b'])
            CatalogCourse(
              id: id,
              title: id.toUpperCase(),
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
          const CatalogCourse(id: 'old', title: '往年课程'),
          CatalogCourse(
            id: 'ta',
            title: '助教课程',
            roles: const ['instructor_assistant'],
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
        ],
      ),
    );
    for (final id in ['a', 'b']) {
      await CourseRollcallsStore.writeSuccess(
        userId: 1,
        courseId: id,
        courseTitle: id,
        records: const [],
      );
    }
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => _Auth()),
        rollcallRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('cold refresh only scans and displays timetable courses', () async {
    await CourseRollcallsStore.writeSuccess(
      userId: 1,
      courseId: 'old',
      courseTitle: '往年课程',
      records: const [],
    );
    final prefs = await SharedPreferences.getInstance();
    for (final id in ['a', 'b']) {
      await prefs.remove(JsonDiskCache.key(CourseRollcallsStore.suffix(1, id)));
    }
    await container.read(courseHistoryProvider.notifier).ensureFresh();
    expect(repo.calls, ['a', 'b']);
    expect(
      container
          .read(courseHistoryProvider)
          .requireValue
          .map((r) => r.courseId)
          .toSet(),
      {'a', 'b'},
    );
  });

  test(
    'appearance during disk load does not cold-scan; repeated pulls skip',
    () async {
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.ensureFresh();
      await notifier.refresh();
      expect(repo.calls, isEmpty);
      expect(container.read(courseHistoryProvider).requireValue, hasLength(2));
    },
  );

  test('only pending course fetched; success consumes signal', () async {
    await container.read(courseHistoryProvider.future);
    container.read(seenInProgressCourseIdsProvider.notifier).state = {'a'};
    final notifier = container.read(courseHistoryProvider.notifier);
    await notifier.refresh();
    await notifier.refresh();
    expect(repo.calls, ['a']);
    expect(container.read(seenInProgressCourseIdsProvider), isEmpty);
  });

  test('failure preserves pending course for retry', () async {
    await container.read(courseHistoryProvider.future);
    container.read(seenInProgressCourseIdsProvider.notifier).state = {'a'};
    repo.fail = true;
    final notifier = container.read(courseHistoryProvider.notifier);
    await notifier.refresh();
    expect(container.read(seenInProgressCourseIdsProvider), {'a'});
    repo.fail = false;
    await notifier.refresh();
    expect(repo.calls, ['a', 'a']);
    expect(container.read(seenInProgressCourseIdsProvider), isEmpty);
  });

  test('new observation during request remains pending', () async {
    await container.read(courseHistoryProvider.future);
    container.read(seenInProgressCourseIdsProvider.notifier).state = {'a'};
    repo.duringFetch = () async {
      container.read(seenInProgressCourseIdsProvider.notifier).state = {'a'};
    };
    await container.read(courseHistoryProvider.notifier).refresh();
    expect(container.read(seenInProgressCourseIdsProvider), {'a'});
  });

  test('shared store refresh prevents fetching from stale memory', () async {
    await CourseRollcallsStore.writeSuccess(
      userId: 1,
      courseId: 'a',
      courseTitle: 'A',
      records: const [],
      at: DateTime.now().subtract(const Duration(days: 1)),
    );
    await container.read(courseHistoryProvider.future);
    await CourseRollcallsStore.writeSuccess(
      userId: 1,
      courseId: 'a',
      courseTitle: 'A',
      records: const [],
    );
    await container.read(courseHistoryProvider.notifier).refresh();
    expect(repo.calls, isEmpty);
  });

  group('candidate window', () {
    List<HistoryCandidate> select(DateTime last, DateTime now) {
      return selectHistoryCandidates(
        courseTitles: {'a': 'A'},
        disks: {
          'a': CourseRollcallsSnapshot(
            courseId: 'a',
            courseTitle: 'A',
            lastSuccessfulFetch: last,
          ),
        },
        seenInProgressCourseIds: {'removed'},
        timetablesByCourse: {
          'a': {
            DateTime.monday: [
              TimetableSlot(
                sequence: 1,
                start: DateTime(2000, 1, 3, 8),
                end: DateTime(2000, 1, 3, 8, 45),
              ),
            ],
          },
        },
        now: now,
      );
    }

    test('end included; last fetch excluded; no class means no fetch', () {
      final end = DateTime(2026, 9, 28, 8, 45);
      expect(select(end.subtract(const Duration(days: 1)), end), hasLength(1));
      expect(select(end, end.add(const Duration(hours: 3))), isEmpty);
      expect(select(end, DateTime(2026, 9, 29, 23)), isEmpty);
    });

    test(
      'two-hour floor retains elapsed session until next eligible refresh',
      () {
        final last = DateTime(2026, 9, 28, 8);
        expect(select(last, DateTime(2026, 9, 28, 9)), isEmpty);
        expect(select(last, DateTime(2026, 9, 28, 10)), hasLength(1));
      },
    );

    test('UTC cache timestamp uses the local timetable calendar', () {
      final last = DateTime(2026, 9, 28, 6).toUtc();
      expect(select(last, DateTime(2026, 9, 28, 8, 45)), hasLength(1));
    });

    test('long absence still finds recurring class', () {
      expect(select(DateTime(2026, 7, 1), DateTime(2026, 9, 28)), hasLength(1));
    });
  });
}
