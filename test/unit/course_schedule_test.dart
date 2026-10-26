import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/core/cache/history_candidates.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid.dart';

class _Repo extends Fake implements AuthRepository {}

class _Assist extends AssistController {
  _Assist(super.ref)
    : super(
        bootstrap: false,
        initial: const AssistUiState(
          ready: true,
          identities: [
            AssistIdentity(
              userId: 2,
              displayName: '协助对象',
              kind: AssistCredentialKind.session,
            ),
          ],
        ),
      );
  void clear() => state = const AssistUiState(ready: true);
}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    switchTo(1);
  }
  void switchTo(int id) {
    state = AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: id, name: '测试用户'),
    );
  }
}

const meetings = [
  CourseMeeting(
    weekday: 1,
    first: 1,
    last: 3,
    startMinutes: 480,
    endMinutes: 630,
    classroom: '教室A',
  ),
  CourseMeeting(
    weekday: 1,
    first: 5,
    last: 6,
    startMinutes: 870,
    endMinutes: 970,
    classroom: '教室B',
  ),
  CourseMeeting(
    weekday: 3,
    first: 7,
    last: 9,
    startMinutes: 1000,
    endMinutes: 1150,
    classroom: '教室C',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'assist timetable saves locally without changing owner and rejects a removed identity',
    () async {
      for (final uid in [1, 2]) {
        await CourseCatalogStore.write(
          uid,
          CourseCatalogSnapshot(
            fetchedAt: DateTime(2026, 10, 26),
            rolesResolved: true,
            courses: const [CatalogCourse(id: 'course', title: '课程')],
          ),
        );
      }
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          assistControllerProvider.overrideWith((ref) => _Assist(ref)),
        ],
      );
      addTearDown(container.dispose);
      final provider = container.read(scopedCourseCatalogProvider(2));
      await container.read(provider.future);
      await container
          .read(provider.notifier)
          .saveMeetings(2, 'course', meetings, expectedOwnerId: 1);
      expect((await CourseScheduleStore.read(2, 'course')), hasLength(3));
      expect(await CourseScheduleStore.read(1, 'course'), isEmpty);
      container.invalidate(provider);
      expect(
        (await container.read(provider.future))!.courses.single.localMeetings,
        hasLength(3),
      );
      (container.read(assistControllerProvider.notifier) as _Assist).clear();
      await expectLater(
        container
            .read(provider.notifier)
            .saveMeetings(2, 'course', [], expectedOwnerId: 1),
        throwsStateError,
      );
      expect(await CourseScheduleStore.read(2, 'course'), hasLength(3));
    },
  );

  test(
    'meetings keep multi-period boundaries and separate classrooms',
    () async {
      await CourseScheduleStore.write(1, 'course', meetings);
      final restored = await CourseScheduleStore.read(1, 'course');
      final course = const CatalogCourse(
        id: 'course',
        title: '测试课程',
      ).withMeetings(restored);
      final blocks = placeTimetableBlocks([course]);
      expect(blocks.map((b) => b.block.id), ['1-3', '5-6', '7-9']);
      expect(blocks.map((b) => b.course.location), ['教室A', '教室B', '教室C']);
      expect(splitContiguousBlocks(course.timetables[1]!).map((b) => b.id), [
        '1-3',
        '5-6',
      ]);
      expect(maxTimetableSequence([course]), 9);
      final adjacent = const CatalogCourse(id: 'adjacent', title: '相邻两次上课')
          .withMeetings([
            meetings.first,
            const CourseMeeting(
              weekday: 1,
              first: 4,
              last: 5,
              startMinutes: 650,
              endMinutes: 750,
              classroom: '教室D',
            ),
          ]);
      expect(placeTimetableBlocks([adjacent]).map((b) => b.block.id), [
        '1-3',
        '4-5',
      ]);
      expect(splitContiguousBlocks(adjacent.timetables[1]!).map((b) => b.id), [
        '1-3',
        '4-5',
      ]);
      expect(course.toJson().containsKey('timetables'), isFalse);
      expect(await CourseScheduleStore.read(2, 'course'), isEmpty);
      await JsonDiskCache.clearAll();
      expect(await CourseScheduleStore.read(1, 'course'), hasLength(3));
    },
  );

  test(
    'overlapping periods or times are rejected without replacing saved meetings',
    () async {
      await CourseScheduleStore.write(1, 'course', meetings);
      await expectLater(
        CourseScheduleStore.write(1, 'course', [
          meetings.first,
          const CourseMeeting(
            weekday: 1,
            first: 3,
            last: 4,
            startMinutes: 700,
            endMinutes: 800,
          ),
        ]),
        throwsFormatException,
      );
      await expectLater(
        CourseScheduleStore.write(1, 'course', [
          meetings.first,
          const CourseMeeting(
            weekday: 1,
            first: 5,
            last: 6,
            startMinutes: 600,
            endMinutes: 700,
          ),
        ]),
        throwsFormatException,
      );
      expect(await CourseScheduleStore.read(1, 'course'), hasLength(3));
    },
  );

  test(
    'catalog restores local schedules without changing the remote cache',
    () async {
      final raw = CourseCatalogSnapshot(
        fetchedAt: DateTime(2026, 10, 26),
        rolesResolved: true,
        courses: const [CatalogCourse(id: 'course', title: '课程')],
      );
      await CourseCatalogStore.write(1, raw);
      await CourseCatalogStore.write(2, raw);
      final container = ProviderContainer(
        overrides: [authControllerProvider.overrideWith((ref) => _Auth())],
      );
      addTearDown(container.dispose);
      await container.read(courseCatalogProvider.future);
      expect(container.read(hasIncompleteCourseScheduleProvider), true);
      await container
          .read(courseCatalogProvider.notifier)
          .saveMeetings(1, 'course', meetings);
      expect(container.read(hasIncompleteCourseScheduleProvider), false);
      expect(
        container
            .read(courseCatalogProvider)
            .requireValue!
            .courses
            .single
            .needsSchedule,
        isFalse,
      );
      expect(
        (await CourseCatalogStore.read(1))!.courses.single.timetables,
        isEmpty,
      );
      container.invalidate(courseCatalogProvider);
      expect(
        (await container.read(
          courseCatalogProvider.future,
        ))!.courses.single.localMeetings,
        hasLength(3),
      );
      (container.read(authControllerProvider.notifier) as _Auth).switchTo(2);
      expect(
        (await container.read(
          courseCatalogProvider.future,
        ))!.courses.single.needsSchedule,
        isTrue,
      );
      expect(container.read(hasIncompleteCourseScheduleProvider), true);
      await expectLater(
        container
            .read(courseCatalogProvider.notifier)
            .saveMeetings(1, 'course', meetings),
        throwsStateError,
      );
    },
  );

  test(
    'platform timetable takes precedence without deleting local entries',
    () {
      final official = CatalogCourse(
        id: 'c',
        title: '课程',
        timetables: {
          2: [
            TimetableSlot(
              sequence: 2,
              start: DateTime(2000, 1, 3, 9),
              end: DateTime(2000, 1, 3, 10),
            ),
          ],
        },
      ).withMeetings(meetings);
      expect(official.timetables.keys, [2]);
      expect(official.localMeetings, hasLength(3));
    },
  );

  CourseRollcallRecord record(DateTime time) => CourseRollcallRecord(
    courseId: 'c',
    courseTitle: '课程',
    rollcallId: time.toIso8601String(),
    rollcallTime: time,
    typeLabel: '二维码',
    signedStatus: '已签到',
    platformStatus: 'on_call_fine',
  );
  List<HistoryCandidate> candidates(
    DateTime last,
    DateTime now, {
    List<CourseRollcallRecord>? records,
    Set<String> seen = const {},
  }) => selectHistoryCandidates(
    courseTitles: {'c': '课程'},
    disks: {
      'c': CourseRollcallsSnapshot(
        courseId: 'c',
        courseTitle: '课程',
        lastSuccessfulFetch: last,
        records:
            records ??
            [
              record(DateTime(2026, 10, 19, 9)),
              record(DateTime(2026, 10, 19, 16)),
              record(DateTime(2026, 10, 21, 9)),
            ],
      ),
    },
    seenInProgressCourseIds: seen,
    timetablesByCourse: const {},
    now: now,
  );

  test(
    'unscheduled history uses every observed weekday and calendar boundaries',
    () {
      expect(
        candidates(DateTime(2026, 10, 26, 10), DateTime(2026, 10, 26, 23, 59)),
        isEmpty,
      );
      expect(
        candidates(
          DateTime(2026, 10, 26, 10),
          DateTime(2026, 10, 27),
        ).single.reason,
        'observed_day_ended',
      );
      expect(
        candidates(DateTime(2026, 10, 27), DateTime(2026, 10, 28, 23)),
        isEmpty,
      );
      expect(
        candidates(DateTime(2026, 10, 27), DateTime(2026, 10, 29)),
        hasLength(1),
      );
      expect(
        candidates(DateTime(2026, 10, 29), DateTime(2026, 11, 2, 23)),
        hasLength(1),
      );
      expect(
        candidates(DateTime(2026, 10, 29), DateTime(2026, 11, 3)),
        hasLength(1),
      );
      expect(
        candidates(
          DateTime(2026, 10, 27).toUtc(),
          DateTime(2026, 10, 28, 23).toUtc(),
        ),
        isEmpty,
      );
    },
  );

  test(
    'empty history does not invent weekdays; live discovery bypasses inference',
    () {
      expect(
        candidates(DateTime(2026, 10, 1), DateTime(2026, 10, 29), records: []),
        hasLength(1),
      );
      expect(
        candidates(
          DateTime(2026, 10, 26, 10),
          DateTime(2026, 10, 26, 11),
          seen: {'c'},
        ),
        hasLength(1),
      );
      expect(
        historyDayEndedBetween(
          {1},
          DateTime(2026, 10, 27),
          DateTime(2026, 10, 20),
        ),
        isFalse,
      );
    },
  );
  test('weekly discovery adds a previously unknown Thursday automatically', () {
    final mondayOnly = [record(DateTime(2026, 10, 26, 15))];
    expect(
      candidates(
        DateTime(2026, 10, 27),
        DateTime(2026, 10, 30),
        records: mondayOnly,
      ),
      isEmpty,
    );
    expect(
      candidates(
        DateTime(2026, 10, 27),
        DateTime(2026, 11, 2),
        records: mondayOnly,
      ).single.reason,
      'week_ended_discovery',
    );
    final learned = [...mondayOnly, record(DateTime(2026, 10, 29, 15))];
    // After the next successful sync, no extra check until Thursday ends.
    expect(
      candidates(
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 5, 23),
        records: learned,
      ),
      isEmpty,
    );
    expect(
      candidates(
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 6),
        records: learned,
      ).single.reason,
      'observed_day_ended',
    );
    expect(
      historyWeekEndedBetween(DateTime(2026, 11, 2), DateTime(2026, 11, 2)),
      isFalse,
    );
    expect(
      historyWeekEndedBetween(
        DateTime(2026, 11, 1, 23).toUtc(),
        DateTime(2026, 11, 2).toUtc(),
      ),
      isTrue,
    );
  });
}
