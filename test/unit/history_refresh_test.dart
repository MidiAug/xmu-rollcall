import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
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

  void switchUser(int id) {
    state = AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: id, name: 'Test'),
    );
  }
}

class _Repository extends Fake implements RollcallRepository {
  final calls = <String>[];
  final students = <int>[];
  bool fail = false;
  Future<void> Function()? duringFetch;
  final records = <String, List<CourseRollcallRecord>>{};

  @override
  Future<List<CourseRollcallRecord>> fetchCourseRollcalls({
    required Object courseId,
    required int studentId,
    String courseTitle = '',
  }) async {
    calls.add('$courseId');
    students.add(studentId);
    await duringFetch?.call();
    if (fail) throw StateError('offline');
    return records['$courseId'] ?? const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository repo;
  late ProviderContainer container;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = _Repository();
    now = DateTime(2026, 10, 23, 18, 20);
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
          const CatalogCourse(id: 'unscheduled', title: '无课表时段的学生课程'),
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
    for (final id in ['a', 'b', 'unscheduled']) {
      await CourseRollcallsStore.writeSuccess(
        userId: 1,
        courseId: id,
        courseTitle: id,
        records: const [],
        at: now,
      );
    }
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => _Auth()),
        rollcallRepositoryProvider.overrideWithValue(repo),
        courseHistoryClockProvider.overrideWithValue(() => now),
      ],
    );
  });

  tearDown(() => container.dispose());

  CourseRollcallRecord externalRow(String status) => CourseRollcallRecord(
    courseId: 'a',
    courseTitle: 'A',
    rollcallId: 'external',
    rollcallTime: DateTime(2026, 10, 26, 8, 15),
    typeLabel: '数字',
    signedStatus: status,
    platformStatus: status == '已签到' ? 'on_call_fine' : 'absent',
  );

  Future<void> mondayCourse(
    DateTime last, {
    int startHour = 8,
    int endHour = 9,
  }) async {
    await CourseCatalogStore.write(
      1,
      CourseCatalogSnapshot(
        fetchedAt: DateTime.now(),
        rolesResolved: true,
        courses: [
          CatalogCourse(
            id: 'a',
            title: 'A',
            timetables: {
              1: [
                TimetableSlot(
                  sequence: 1,
                  start: DateTime(2000, 1, 3, startHour),
                  end: DateTime(2000, 1, 3, endHour),
                ),
              ],
            },
          ),
        ],
      ),
    );
    await CourseRollcallsStore.writeSuccess(
      userId: 1,
      courseId: 'a',
      courseTitle: 'A',
      records: [externalRow('未签到')],
      at: last,
    );
  }

  test(
    'external attendance becomes signed after a general pull during class',
    () async {
      now = DateTime(2026, 10, 26, 8, 30);
      await mondayCourse(now);
      await container.read(courseHistoryProvider.future);
      repo.records['a'] = [externalRow('已签到')];
      now = now.add(const Duration(seconds: 20));
      await container.read(courseHistoryProvider.notifier).refresh();
      expect(repo.calls, ['a']);
      expect(container.read(seenInProgressCourseIdsProvider), isEmpty);
      expect(
        container.read(courseHistoryProvider).requireValue.single.signedStatus,
        '已签到',
      );
      await container.read(courseHistoryProvider.notifier).refresh();
      expect(repo.calls, ['a']);
    },
  );

  test(
    '11am course makes no request at 10am even without a history cache',
    () async {
      now = DateTime(2026, 10, 26, 10);
      await mondayCourse(now, startHour: 11, endHour: 12);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(
        JsonDiskCache.key(CourseRollcallsStore.suffix(1, 'a')),
      );
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.ensureFresh();
      await notifier.refresh();
      expect(repo.calls, isEmpty);
      now = DateTime(2026, 10, 26, 10, 30);
      repo.records['a'] = [externalRow('已签到')];
      await notifier.refresh();
      expect(repo.calls, ['a']);
      await notifier.refresh();
      expect(repo.calls, ['a']);
      now = DateTime(2026, 10, 26, 12, 40);
      await notifier.refresh();
      now = now.add(const Duration(hours: 1));
      await notifier.refresh();
      expect(repo.calls, ['a', 'a']);
    },
  );

  test(
    'late external attendance gets one final sync, persisted across rebuild',
    () async {
      now = DateTime(2026, 10, 26, 9, 40);
      await mondayCourse(DateTime(2026, 10, 26, 8, 30));
      repo.records['a'] = [externalRow('已签到')];
      await container.read(courseHistoryProvider.notifier).refresh();
      expect(repo.calls, ['a']);
      expect(
        container.read(courseHistoryProvider).requireValue.single.signedStatus,
        '已签到',
      );
      now = now.add(const Duration(hours: 1));
      container.invalidate(courseHistoryProvider);
      await container.read(courseHistoryProvider.future);
      await container.read(courseHistoryProvider.notifier).refresh();
      expect(repo.calls, ['a']);
      now = DateTime(2026, 11, 2, 8, 30);
      await container.read(courseHistoryProvider.notifier).refresh();
      expect(repo.calls, ['a', 'a']);
    },
  );

  test(
    'failed final sync keeps the opportunity and retries after the short gate',
    () async {
      now = DateTime(2026, 10, 26, 9, 40);
      await mondayCourse(DateTime(2026, 10, 26, 8, 30));
      repo.fail = true;
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.refresh();
      await notifier.refresh();
      expect(repo.calls, ['a']);
      expect(
        (await CourseRollcallsStore.read(1, 'a'))!.checkedThrough,
        DateTime(2026, 10, 26, 8, 30),
      );
      repo.fail = false;
      repo.records['a'] = [externalRow('已签到')];
      now = now.add(const Duration(seconds: 15));
      await notifier.refresh();
      now = now.add(const Duration(minutes: 1));
      await notifier.refresh();
      expect(repo.calls, ['a', 'a']);
    },
  );

  test(
    'a request crossing the cutoff does not consume the final sync',
    () async {
      now = DateTime(2026, 10, 26, 9, 29, 50);
      await mondayCourse(DateTime(2026, 10, 26, 8, 30));
      repo.records['a'] = [externalRow('已签到')];
      repo.duringFetch = () async {
        now = DateTime(2026, 10, 26, 9, 30, 5);
        repo.duringFetch = null;
      };
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.refresh();
      now = DateTime(2026, 10, 26, 9, 30, 10);
      await notifier.refresh();
      now = DateTime(2026, 10, 26, 10);
      await notifier.refresh();
      expect(repo.calls, ['a', 'a']);
    },
  );

  test(
    'empty history is probed on demand and learns timing from external attendance',
    () async {
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.ensureFresh();
      expect(repo.calls, isEmpty);
      repo.records['unscheduled'] = [
        CourseRollcallRecord(
          courseId: 'unscheduled',
          courseTitle: 'Unknown',
          rollcallId: 'new-external',
          rollcallTime: now,
          typeLabel: '二维码',
          signedStatus: '已签到',
          platformStatus: 'on_call_fine',
        ),
      ];
      await notifier.refresh();
      expect(repo.calls, ['unscheduled']);
      expect(
        container
            .read(courseHistoryProvider)
            .requireValue
            .any((r) => r.rollcallId == 'new-external'),
        isTrue,
      );
      expect(
        (await CourseRollcallsStore.read(1, 'unscheduled'))!.timingEvidence,
        isNotEmpty,
      );
    },
  );

  test(
    'manual pull joining a slow appearance does not re-query covered courses',
    () async {
      now = DateTime(2026, 10, 26, 8, 30);
      final prefs = await SharedPreferences.getInstance();
      for (final id in ['a', 'b', 'unscheduled']) {
        await prefs.remove(
          JsonDiskCache.key(CourseRollcallsStore.suffix(1, id)),
        );
      }
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      repo.duringFetch = () async {
        repo.duringFetch = null;
        entered.complete();
        await release.future;
        now = now.add(const Duration(minutes: 2));
      };
      final notifier = container.read(courseHistoryProvider.notifier);
      final appear = notifier.ensureFresh();
      await entered.future;
      final pull = notifier.refresh();
      release.complete();
      await Future.wait([appear, pull]);
      expect(repo.calls, ['a', 'b', 'unscheduled']);
    },
  );

  test(
    'user supplied meeting receives the same external-attendance refresh window',
    () async {
      now = DateTime(2026, 10, 26, 8, 30);
      await CourseCatalogStore.write(
        1,
        CourseCatalogSnapshot(
          fetchedAt: DateTime.now(),
          rolesResolved: true,
          courses: const [CatalogCourse(id: 'a', title: 'A')],
        ),
      );
      await CourseScheduleStore.write(1, 'a', const [
        CourseMeeting(
          weekday: 1,
          first: 1,
          last: 2,
          startMinutes: 480,
          endMinutes: 540,
        ),
      ]);
      await CourseRollcallsStore.writeSuccess(
        userId: 1,
        courseId: 'a',
        courseTitle: 'A',
        records: [externalRow('未签到')],
        at: now,
      );
      repo.records['a'] = [externalRow('已签到')];
      now = now.add(const Duration(seconds: 20));
      await container.read(courseHistoryProvider.notifier).refresh();
      expect(repo.calls, ['a']);
      expect(
        container.read(courseHistoryProvider).requireValue.single.signedStatus,
        '已签到',
      );
      now = DateTime(2026, 10, 26, 10);
      await container.read(courseHistoryProvider.notifier).refresh();
      now = DateTime(2026, 10, 27, 10);
      await container.read(courseHistoryProvider.notifier).refresh();
      expect(repo.calls, ['a', 'a']);
    },
  );

  test(
    'manual fallback finds an external answer outside inferred weekdays',
    () async {
      now = DateTime(2026, 10, 27, 12);
      await CourseCatalogStore.write(
        1,
        CourseCatalogSnapshot(
          fetchedAt: DateTime.now(),
          rolesResolved: true,
          courses: const [CatalogCourse(id: 'a', title: 'A')],
        ),
      );
      await CourseRollcallsStore.writeSuccess(
        userId: 1,
        courseId: 'a',
        courseTitle: 'A',
        records: [externalRow('未签到')],
        at: DateTime(2026, 10, 26, 12),
      );
      repo.records['a'] = [externalRow('已签到')];
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.ensureFresh();
      expect(repo.calls, isEmpty);
      await notifier.refresh();
      expect(repo.calls, ['a']);
      expect(
        container.read(courseHistoryProvider).requireValue.single.signedStatus,
        '已签到',
      );
    },
  );

  test(
    'cold refresh includes enrolled courses without timetable slots',
    () async {
      now = DateTime(2026, 10, 26, 8, 30);
      await CourseRollcallsStore.writeSuccess(
        userId: 1,
        courseId: 'old',
        courseTitle: '往年课程',
        records: const [],
      );
      final prefs = await SharedPreferences.getInstance();
      for (final id in ['a', 'b', 'unscheduled']) {
        await prefs.remove(
          JsonDiskCache.key(CourseRollcallsStore.suffix(1, id)),
        );
      }
      await container.read(courseHistoryProvider.notifier).ensureFresh();
      expect(repo.calls, ['a', 'b', 'unscheduled']);
      expect(
        container
            .read(courseHistoryProvider)
            .requireValue
            .map((r) => r.courseId)
            .toSet(),
        {'a', 'b', 'unscheduled'},
      );
    },
  );

  test(
    'general pulls probe unknown timing but skip closed scheduled courses',
    () async {
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.ensureFresh();
      await notifier.refresh();
      await notifier.refresh();
      expect(repo.calls, ['unscheduled']);
      expect(container.read(courseHistoryProvider).requireValue, hasLength(3));
    },
  );

  test(
    'later general pulls only re-probe courses whose timing is unknown',
    () async {
      now = DateTime(2026, 10, 26, 10);
      final prefs = await SharedPreferences.getInstance();
      for (final id in ['a', 'b', 'unscheduled']) {
        await prefs.remove(
          JsonDiskCache.key(CourseRollcallsStore.suffix(1, id)),
        );
      }
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.refresh();
      expect(repo.calls, ['a', 'b', 'unscheduled']);
      now = now.add(const Duration(seconds: 16));
      await notifier.refresh();
      expect(repo.calls, ['a', 'b', 'unscheduled', 'unscheduled']);
    },
  );

  test(
    'Monday Wednesday course skips Tuesday after Monday was checked',
    () async {
      now = DateTime(2026, 10, 27, 10);
      await CourseCatalogStore.write(
        1,
        CourseCatalogSnapshot(
          fetchedAt: DateTime.now(),
          rolesResolved: true,
          courses: [
            CatalogCourse(
              id: 'a',
              title: 'A',
              timetables: {
                for (final day in [DateTime.monday, DateTime.wednesday])
                  day: [
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
      await CourseRollcallsStore.writeSuccess(
        userId: 1,
        courseId: 'a',
        courseTitle: 'A',
        records: const [],
        at: DateTime(2026, 10, 26, 10),
      );
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.ensureFresh();
      await notifier.refresh();
      expect(repo.calls, isEmpty);
      now = DateTime(2026, 10, 28, 10);
      await notifier.refresh();
      expect(repo.calls, ['a']);
      now = DateTime(2026, 10, 29, 10);
      await notifier.refresh();
      expect(repo.calls, ['a']);
    },
  );

  test(
    'unscheduled course restores signed history and can refresh alone',
    () async {
      final record = CourseRollcallRecord(
        courseId: 'unscheduled',
        courseTitle: '无课表时段的学生课程',
        rollcallId: 'previous',
        rollcallTime: now.subtract(const Duration(days: 7)),
        typeLabel: '二维码',
        signedStatus: '已签到',
        platformStatus: 'on_call_fine',
      );
      await CourseRollcallsStore.writeSuccess(
        userId: 1,
        courseId: 'unscheduled',
        courseTitle: record.courseTitle,
        records: [record],
        at: now,
      );
      final rows = await container.read(courseHistoryProvider.future);
      expect(
        rows.where((r) => r.courseId == 'unscheduled').single.rollcallId,
        'previous',
      );
      repo.records['unscheduled'] = [record];
      await container
          .read(courseHistoryProvider.notifier)
          .refreshCourse('unscheduled');
      expect(repo.calls, ['unscheduled']);
      expect(
        container
            .read(courseHistoryProvider)
            .requireValue
            .where((r) => r.courseId == 'unscheduled')
            .single
            .signedStatus,
        '已签到',
      );
    },
  );

  test('only pending course fetched; success consumes signal', () async {
    await container.read(courseHistoryProvider.future);
    container.read(seenInProgressCourseIdsProvider.notifier).state = {'a'};
    final notifier = container.read(courseHistoryProvider.notifier);
    await notifier.ensureFresh();
    await notifier.ensureFresh();
    expect(repo.calls, ['a']);
    expect(container.read(seenInProgressCourseIdsProvider), isEmpty);
  });

  test(
    'confirmed attendance is visible while a later course is blocked',
    () async {
      final old = CourseRollcallRecord(
        courseId: 'a',
        courseTitle: 'A',
        rollcallId: 'recent',
        rollcallTime: now,
        typeLabel: '数字',
        signedStatus: '未签到',
        platformStatus: 'absent',
      );
      await CourseRollcallsStore.writeSuccess(
        userId: 1,
        courseId: 'a',
        courseTitle: 'A',
        records: [old],
        at: now,
      );
      await container.read(courseHistoryProvider.future);
      container.read(seenInProgressCourseIdsProvider.notifier).state = {
        'a',
        'b',
      };
      repo.records['a'] = [
        CourseRollcallRecord(
          courseId: 'a',
          courseTitle: 'A',
          rollcallId: 'recent',
          rollcallTime: now,
          typeLabel: '数字',
          signedStatus: '已签到',
          platformStatus: 'on_call_fine',
        ),
      ];
      final blocked = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      repo.duringFetch = () async {
        if (repo.calls.last == 'b') {
          blocked.complete();
          await release.future;
        }
      };
      var finished = false;
      final refresh = container
          .read(courseHistoryProvider.notifier)
          .refresh()
          .then((_) => finished = true);
      await blocked.future;
      expect(finished, isFalse);
      expect(
        container
            .read(courseHistoryProvider)
            .requireValue
            .singleWhere((r) => r.rollcallId == 'recent')
            .signedStatus,
        '已签到',
      );
      release.complete();
      await refresh;
      expect(finished, isTrue);
    },
  );

  test(
    'manual refresh prioritizes changed attendance without extra requests',
    () async {
      await container.read(courseHistoryProvider.future);
      container.read(seenInProgressCourseIdsProvider.notifier).state = {
        'unscheduled',
      };
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.refresh();
      expect(repo.calls, ['unscheduled']);
      await notifier.refresh();
      expect(repo.calls, ['unscheduled']);
    },
  );

  test('failure preserves pending course for retry', () async {
    await container.read(courseHistoryProvider.future);
    container.read(seenInProgressCourseIdsProvider.notifier).state = {'a'};
    repo.fail = true;
    final notifier = container.read(courseHistoryProvider.notifier);
    await notifier.ensureFresh();
    expect(container.read(seenInProgressCourseIdsProvider), {'a'});
    repo.fail = false;
    now = now.add(const Duration(seconds: 16));
    await notifier.ensureFresh();
    expect(repo.calls, ['a', 'a']);
    expect(container.read(seenInProgressCourseIdsProvider), isEmpty);
  });

  test('new observation during request remains pending', () async {
    await container.read(courseHistoryProvider.future);
    container.read(seenInProgressCourseIdsProvider.notifier).state = {'a'};
    repo.duringFetch = () async {
      container.read(seenInProgressCourseIdsProvider.notifier).state = {'a'};
    };
    await container.read(courseHistoryProvider.notifier).ensureFresh();
    expect(container.read(seenInProgressCourseIdsProvider), {'a'});
  });

  test('shared store refresh prevents fetching from stale memory', () async {
    await CourseRollcallsStore.writeSuccess(
      userId: 1,
      courseId: 'a',
      courseTitle: 'A',
      records: const [],
      at: now.subtract(const Duration(days: 1)),
    );
    await container.read(courseHistoryProvider.future);
    await CourseRollcallsStore.writeSuccess(
      userId: 1,
      courseId: 'a',
      courseTitle: 'A',
      records: const [],
      at: now,
    );
    await container.read(courseHistoryProvider.notifier).ensureFresh();
    expect(repo.calls, isEmpty);
  });

  CourseRollcallRecord signed(String id, int hour, int minute) =>
      CourseRollcallRecord(
        courseId: 'a',
        courseTitle: '测试课程',
        rollcallId: id,
        rollcallTime: DateTime(2026, 10, 23, hour, minute),
        typeLabel: '二维码签到',
        signedStatus: '已签到',
        platformStatus: 'on_call_fine',
      );

  Future<void> seedFirstAttendance() => CourseRollcallsStore.writeSuccess(
    userId: 1,
    courseId: 'a',
    courseTitle: '测试课程',
    records: [signed('first', 16, 37)],
    at: DateTime(2026, 10, 23, 16, 46, 49),
  );

  test(
    'manual selected course discovers the 18:17 second event within two hours',
    () async {
      await seedFirstAttendance();
      repo.records['a'] = [signed('first', 16, 37), signed('second', 18, 17)];
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.ensureFresh();
      expect(repo.calls, isEmpty);
      await notifier.refresh(courseId: 'a');
      expect(repo.calls, ['a']);
      final records = container.read(courseHistoryProvider).requireValue;
      expect(records.where((r) => r.courseId == 'a').map((r) => r.rollcallId), [
        'second',
        'first',
      ]);
      await notifier.refresh(courseId: 'a');
      expect(repo.calls, ['a']);
      now = now.add(const Duration(seconds: 15));
      await notifier.refresh(courseId: 'a');
      expect(repo.calls, ['a', 'a']);
    },
  );

  test(
    'appearance during the same class discovers a later event without live observation',
    () async {
      await CourseCatalogStore.write(
        1,
        CourseCatalogSnapshot(
          fetchedAt: now,
          rolesResolved: true,
          courses: [
            CatalogCourse(
              id: 'a',
              title: '测试课程',
              timetables: {
                DateTime.friday: [
                  TimetableSlot(
                    sequence: 7,
                    start: DateTime(2000, 1, 3, 16, 30),
                    end: DateTime(2000, 1, 3, 18, 10),
                  ),
                ],
              },
            ),
          ],
        ),
      );
      await seedFirstAttendance();
      repo.records['a'] = [signed('first', 16, 37), signed('second', 18, 17)];
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.ensureFresh();
      expect(repo.calls, ['a']);
      expect(
        container
            .read(courseHistoryProvider)
            .requireValue
            .map((r) => r.rollcallId),
        ['second', 'first'],
      );
      now = now.add(const Duration(seconds: 30));
      await notifier.ensureFresh();
      expect(repo.calls, ['a']);
      now = now.add(const Duration(seconds: 30));
      await notifier.ensureFresh();
      expect(repo.calls, ['a', 'a']);
    },
  );

  test(
    'manual failure is short-throttled and keeps prior signed history',
    () async {
      await seedFirstAttendance();
      repo.fail = true;
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.refresh(courseId: 'a');
      await notifier.refresh(courseId: 'a');
      expect(repo.calls, ['a']);
      expect(
        container
            .read(courseHistoryProvider)
            .requireValue
            .any((r) => r.rollcallId == 'first'),
        isTrue,
      );
      now = now.add(const Duration(seconds: 15));
      repo.fail = false;
      await notifier.refresh(courseId: 'a');
      expect(repo.calls, ['a', 'a']);
    },
  );

  test(
    'concurrent manual pulls coalesce and a different requested course is not lost',
    () async {
      await container.read(courseHistoryProvider.future);
      final gate = Completer<void>();
      final entered = Completer<void>();
      repo.duringFetch = () async {
        repo.duringFetch = null;
        entered.complete();
        await gate.future;
      };
      final notifier = container.read(courseHistoryProvider.notifier);
      final first = notifier.refresh(courseId: 'a');
      await entered.future;
      final repeat = notifier.refresh(courseId: 'a');
      final other = notifier.refresh(courseId: 'b');
      final otherAgain = notifier.refresh(courseId: 'b');
      gate.complete();
      await Future.wait([first, repeat, other, otherAgain]);
      expect(repo.calls, ['a', 'b']);
    },
  );

  test(
    'switching account does not reuse the previous account short throttle',
    () async {
      await CourseCatalogStore.write(2, (await CourseCatalogStore.read(1))!);
      final notifier = container.read(courseHistoryProvider.notifier);
      await notifier.refresh(courseId: 'a');
      (container.read(authControllerProvider.notifier) as _Auth).switchUser(2);
      await container.read(courseHistoryProvider.future);
      await container
          .read(courseHistoryProvider.notifier)
          .refresh(courseId: 'a');
      expect(repo.students, [1, 2]);
    },
  );

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

    test(
      'post-class final remains pending until the grace window was covered',
      () {
        final end = DateTime(2026, 9, 28, 8, 45);
        expect(
          select(end.subtract(const Duration(days: 1)), end),
          hasLength(1),
        );
        expect(select(end, end.add(const Duration(hours: 3))), hasLength(1));
        expect(select(end, DateTime(2026, 9, 29, 23)), hasLength(1));
        expect(
          select(
            end.add(const Duration(minutes: 30)),
            DateTime(2026, 9, 29, 23),
          ),
          isEmpty,
        );
      },
    );

    test('active and just-ended classes bypass the two-hour floor', () {
      final last = DateTime(2026, 9, 28, 8);
      expect(select(last, DateTime(2026, 9, 28, 9)), hasLength(1));
      expect(select(last, DateTime(2026, 9, 28, 10)), hasLength(1));
    });

    test('UTC cache timestamp uses the local timetable calendar', () {
      final last = DateTime(2026, 9, 28, 6).toUtc();
      expect(select(last, DateTime(2026, 9, 28, 8, 45)), hasLength(1));
    });

    test('long absence still finds recurring class', () {
      expect(select(DateTime(2026, 7, 1), DateTime(2026, 9, 28)), hasLength(1));
    });
  });
}
