import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/core/cache/history_candidates.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

final monday = {
  1: [
    TimetableSlot(
      sequence: 1,
      start: DateTime(2000, 1, 3, 8),
      end: DateTime(2000, 1, 3, 9),
    ),
  ],
};

List<HistoryCandidate> plan(
  DateTime now,
  DateTime last, {
  Map<int, List<TimetableSlot>>? timetable,
  bool manual = false,
  DateTime? through,
  List<DateTime> evidence = const [],
  bool changed = false,
}) => selectHistoryCandidates(
  courseTitles: {'c': 'Course'},
  disks: {
    'c': CourseRollcallsSnapshot(
      courseId: 'c',
      courseTitle: 'Course',
      lastSuccessfulFetch: last,
      checkedThrough: through,
      observedTimes: evidence,
    ),
  },
  timetablesByCourse: {'c': timetable ?? const {}},
  seenInProgressCourseIds: changed ? {'c'} : {},
  now: now,
  manualRefresh: manual,
);

CourseRollcallRecord row(DateTime time) => CourseRollcallRecord(
  courseId: 'c',
  courseTitle: 'Course',
  rollcallId: 'r',
  rollcallTime: time,
  typeLabel: '数字',
  signedStatus: '已签到',
  platformStatus: 'on_call_fine',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'scheduled manual window starts 30 minutes early and includes end plus 30',
    () {
      final last = DateTime(2026, 10, 26, 7);
      for (final time in [
        DateTime(2026, 10, 26, 7, 30),
        DateTime(2026, 10, 26, 8),
        DateTime(2026, 10, 26, 9, 29, 59),
      ]) {
        expect(
          plan(time, last, timetable: monday, manual: true).single.reason,
          'scheduled_window',
        );
      }
      expect(
        plan(
          DateTime(2026, 10, 26, 7, 29, 59),
          last,
          timetable: monday,
          manual: true,
        ),
        isEmpty,
      );
      expect(
        plan(
          DateTime(2026, 10, 26, 9, 30),
          last,
          timetable: monday,
        ).single.reason,
        'scheduled_final',
      );
    },
  );

  test('manual refresh bypasses passive freshness within a class', () {
    final last = DateTime(2026, 10, 26, 8, 10);
    final now = last.add(const Duration(seconds: 20));
    expect(plan(now, last, timetable: monday), isEmpty);
    expect(plan(now, last, timetable: monday, manual: true), hasLength(1));
    expect(
      plan(last.add(const Duration(seconds: 60)), last, timetable: monday),
      hasLength(1),
    );
  });

  test('11am meeting skips 10am and opens exactly at 10:30', () {
    final timetable = {
      1: [
        TimetableSlot(
          sequence: 4,
          start: DateTime(2000, 1, 3, 11),
          end: DateTime(2000, 1, 3, 12),
        ),
      ],
    };
    final last = DateTime(2026, 10, 26, 9);
    for (final time in [
      DateTime(2026, 10, 26, 10),
      DateTime(2026, 10, 26, 10, 29, 59),
    ]) {
      expect(plan(time, last, timetable: timetable, manual: true), isEmpty);
      expect(plan(time, last, timetable: timetable), isEmpty);
    }
    expect(
      plan(
        DateTime(2026, 10, 26, 10, 30),
        last,
        timetable: timetable,
        manual: true,
      ).single.reason,
      'scheduled_window',
    );
  });

  test('pre-class window can start on the previous calendar day', () {
    final timetable = {
      2: [
        TimetableSlot(
          sequence: 1,
          start: DateTime(2000, 1, 3, 0, 10),
          end: DateTime(2000, 1, 3, 1),
        ),
      ],
    };
    final last = DateTime(2026, 10, 26, 20);
    expect(
      plan(
        DateTime(2026, 10, 26, 23, 39, 59),
        last,
        timetable: timetable,
        manual: true,
      ),
      isEmpty,
    );
    expect(
      plan(
        DateTime(2026, 10, 26, 23, 40),
        last,
        timetable: timetable,
        manual: true,
      ).single.reason,
      'scheduled_window',
    );
  });

  test('one final sync closes the meeting and next Monday opens another', () {
    final during = DateTime(2026, 10, 26, 9);
    final after = DateTime(2026, 10, 26, 10);
    expect(
      plan(after, during, timetable: monday).single.reason,
      'scheduled_final',
    );
    for (final now in [
      after,
      DateTime(2026, 10, 27, 12),
      DateTime(2026, 11, 2, 7, 29, 59),
    ]) {
      expect(plan(now, after, timetable: monday, manual: true), isEmpty);
    }
    expect(
      plan(DateTime(2026, 11, 2, 7, 30), after, timetable: monday),
      hasLength(1),
    );
  });

  test('cutoff is not consumed by a response that started before it', () {
    final responseEnd = DateTime(2026, 10, 26, 9, 30, 10);
    expect(
      plan(
        responseEnd,
        responseEnd,
        timetable: monday,
        through: DateTime(2026, 10, 26, 9, 29, 50),
      ).single.reason,
      'scheduled_final',
    );
    expect(
      plan(
        responseEnd,
        responseEnd,
        timetable: monday,
        through: DateTime(2026, 10, 26, 9, 30),
      ),
      isEmpty,
    );
  });

  test(
    'long absences coalesce to one final query and UTC uses local calendar',
    () {
      final now = DateTime(2026, 10, 27, 12);
      expect(
        plan(now.toUtc(), DateTime(2026, 1, 1).toUtc(), timetable: monday),
        hasLength(1),
      );
      expect(
        plan(
          now.toUtc(),
          DateTime(2026, 10, 26, 10).toUtc(),
          timetable: monday,
        ),
        isEmpty,
      );
    },
  );

  test('multiple meetings on one day have independent closing boundaries', () {
    final timetable = {
      1: [
        ...monday[1]!,
        TimetableSlot(
          sequence: 7,
          start: DateTime(2000, 1, 3, 16),
          end: DateTime(2000, 1, 3, 17),
        ),
      ],
    };
    final last = DateTime(2026, 10, 26, 10);
    expect(
      plan(DateTime(2026, 10, 26, 15), last, timetable: timetable),
      isEmpty,
    );
    expect(
      plan(DateTime(2026, 10, 26, 16), last, timetable: timetable),
      hasLength(1),
    );
    expect(
      plan(
        DateTime(2026, 10, 26, 18),
        last,
        timetable: timetable,
      ).single.reason,
      'scheduled_final',
    );
  });

  test('grace window can cross midnight', () {
    final late = {
      1: [
        TimetableSlot(
          sequence: 11,
          start: DateTime(2000, 1, 3, 23),
          end: DateTime(2000, 1, 3, 23, 50),
        ),
      ],
    };
    final last = DateTime(2026, 10, 26, 23);
    expect(
      plan(DateTime(2026, 10, 27, 0, 10), last, timetable: late).single.reason,
      'scheduled_window',
    );
    expect(
      plan(DateTime(2026, 10, 27, 0, 21), last, timetable: late).single.reason,
      'scheduled_final',
    );
  });

  test('inference covers continuous periods, all observed days, and UTC', () {
    final times = [DateTime(2026, 10, 19, 16, 30), DateTime(2026, 10, 21, 9)];
    final windows = inferHistoryWindows(times.map((t) => t.toUtc()));
    expect(windows.map((w) => w.weekday).toSet(), {1, 3});
    final afternoon = windows.singleWhere((w) => w.weekday == 1);
    expect(afternoon.startMinute, lessThanOrEqualTo(16 * 60 + 30));
    expect(afternoon.endMinute, 18 * 60 + 20);
    expect(
      plan(
        DateTime(2026, 10, 26, 17),
        DateTime(2026, 10, 26, 12),
        evidence: times,
      ).single.reason,
      'inferred_window',
    );
  });

  test(
    'inferred windows only rank manual probes; outside-window answers can be found',
    () {
      final evidence = [DateTime(2026, 10, 19, 16, 30)];
      final last = DateTime(2026, 10, 26, 20);
      final now = DateTime(2026, 10, 27, 12);
      expect(plan(now, last, evidence: evidence), isEmpty);
      expect(
        plan(now, last, evidence: evidence, manual: true).single.reason,
        'inferred_fallback',
      );
    },
  );

  test(
    'empty histories are demand-driven and do not invent a weekly schedule',
    () {
      final last = DateTime(2026, 10, 1);
      final now = DateTime(2026, 10, 27);
      expect(plan(now, last), isEmpty);
      expect(plan(now, last, manual: true).single.reason, 'unknown_probe');
      expect(
        plan(now, last, timetable: monday, changed: true).single.reason,
        'activity_changed',
      );
    },
  );

  test('reliable schedule overrides contradictory historical timing', () {
    expect(
      plan(
        DateTime(2026, 10, 27, 16),
        DateTime(2026, 10, 26, 10),
        timetable: monday,
        manual: true,
        evidence: [DateTime(2026, 10, 20, 16)],
      ),
      isEmpty,
    );
  });

  test(
    'candidate priority puts changed and scheduled courses before uncertain probes',
    () {
      final now = DateTime(2026, 10, 26, 8, 30);
      final result = selectHistoryCandidates(
        courseTitles: {
          for (final id in ['unknown', 'inferred', 'scheduled', 'changed'])
            id: id,
        },
        disks: {
          for (final id in ['unknown', 'inferred', 'scheduled', 'changed'])
            id: CourseRollcallsSnapshot(
              courseId: id,
              courseTitle: id,
              lastSuccessfulFetch: DateTime(2026, 10, 26, 8),
              observedTimes: id == 'inferred'
                  ? [DateTime(2026, 10, 19, 8, 30)]
                  : [],
            ),
        },
        timetablesByCourse: {'scheduled': monday},
        seenInProgressCourseIds: {'changed'},
        now: now,
        manualRefresh: true,
      );
      expect(result.map((c) => c.courseId), [
        'changed',
        'scheduled',
        'inferred',
        'unknown',
      ]);
    },
  );

  test(
    'timing evidence and coverage survive empty responses, failure, and disk reload',
    () async {
      final time = DateTime(2026, 10, 19, 16, 30);
      final start = DateTime(2026, 10, 26, 18, 49, 50);
      await CourseRollcallsStore.writeSuccess(
        userId: 1,
        courseId: 'c',
        courseTitle: 'Course',
        records: [row(time)],
        at: start,
      );
      final empty = await CourseRollcallsStore.writeSuccess(
        userId: 1,
        courseId: 'c',
        courseTitle: 'Course',
        records: [],
        checkedThrough: start,
        at: start.add(const Duration(seconds: 20)),
      );
      expect(empty.records, isEmpty);
      expect(empty.timingEvidence.single.isAtSameMomentAs(time), isTrue);
      await CourseRollcallsStore.writeFailure(
        userId: 1,
        courseId: 'c',
        courseTitle: 'Course',
        error: 'offline',
        previous: empty,
      );
      final restored = (await CourseRollcallsStore.read(1, 'c'))!;
      expect(restored.checkedThrough, start);
      expect(inferHistoryWindows(restored.timingEvidence), hasLength(1));
      expect(await CourseRollcallsStore.read(2, 'c'), isNull);
    },
  );

  test('legacy snapshots remain readable and use existing record times', () {
    final old = CourseRollcallsSnapshot.fromJson({
      'courseId': 'c',
      'lastSuccessfulFetch': '2026-10-26T10:00:00',
      'records': [row(DateTime(2026, 10, 19, 9)).toJson()],
    });
    expect(old.checkedThrough, isNull);
    expect(inferHistoryWindows(old.timingEvidence), hasLength(1));
  });

  test(
    'an older request completing late cannot replace newer coverage',
    () async {
      final newer = DateTime(2026, 10, 26, 10);
      await CourseRollcallsStore.writeSuccess(
        userId: 1,
        courseId: 'c',
        courseTitle: 'Course',
        records: [row(newer)],
        at: newer,
        checkedThrough: newer,
      );
      await CourseRollcallsStore.writeSuccess(
        userId: 1,
        courseId: 'c',
        courseTitle: 'Course',
        records: [],
        at: newer.add(const Duration(minutes: 1)),
        checkedThrough: newer.subtract(const Duration(minutes: 1)),
      );
      final stored = (await CourseRollcallsStore.read(1, 'c'))!;
      expect(stored.checkedThrough, newer);
      expect(stored.records, hasLength(1));
    },
  );
}
