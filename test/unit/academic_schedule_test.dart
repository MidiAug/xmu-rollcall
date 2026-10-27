import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/core/cache/history_candidates.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/schedule/academic_client.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/schedule/schedule_detection.dart';

Map<String, dynamic> meeting({
  String code = 'CS1',
  String title = '计算机网络',
  String cls = 'A',
  String mask = '101000',
  int day = 1,
  int first = 3,
  int last = 4,
  String room = '教学楼101',
}) => {
  'KCDM': code,
  'KCMC': title,
  'BJDM': cls,
  'BJMC': cls,
  'JSXM': '测试教师',
  'ZCBH': mask,
  'XQ': '$day',
  'KSJCDM': '$first',
  'JSJCDM': '$last',
  'JASMC': room,
};
AcademicSchedule schedule({
  List<Map<String, dynamic>>? rows,
  List<Map<String, dynamic>> changes = const [],
}) => AcademicSchedule.parse(
  term: '20261',
  monday: DateTime(2026, 9, 7),
  at: DateTime(2026, 9, 7),
  payload: {
    'success': true,
    'pkjgList': rows ?? [meeting()],
    'ttbList': changes,
  },
  clock: {
    3: (start: 610, end: 655),
    4: (start: 665, end: 710),
    5: (start: 870, end: 915),
    6: (start: 925, end: 970),
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'teacher and both assistant roles never consume the student academic match',
    () {
      final academic = schedule();
      final courses = academic.apply([
        const CatalogCourse(id: 'student', title: '计算机网络', courseCode: 'CS1'),
        for (final role in [
          'instructor',
          'instructor_assistant',
          'student_assistant',
        ])
          CatalogCourse(
            id: role,
            title: '计算机网络',
            courseCode: 'CS1',
            roles: [role],
          ),
      ]);
      expect(courses.first.academicMatched, isTrue);
      expect(courses.skip(1).every((c) => !c.academicMatched), isTrue);
      expect(academic.displayOnlyCourses(const []).map((c) => c.title), [
        '计算机网络',
      ]);
    },
  );
  test(
    'authoritative odd weeks, actual period clock, room, account disk isolation',
    () async {
      final academic = schedule();
      final courses = academic.apply([
        const CatalogCourse(
          id: 'tron',
          title: '计算机网络',
          courseCode: 'CS1',
          location: '旧教室',
        ),
      ]);
      final course = courses.single;
      expect(course.id, 'tron');
      expect(course.academicMatched, isTrue);
      expect(
        course.timetablesOn(DateTime(2026, 9, 7))[1]!.single.classroom,
        '教学楼101',
      );
      expect(course.timetablesOn(DateTime(2026, 9, 14)), isEmpty);
      expect(
        course.timetablesOn(DateTime(2026, 9, 21))[1]!.single.start.minute,
        10,
      );
      expect(course.timetablesOn(DateTime(2027, 9, 7)), isEmpty);
      await AcademicScheduleStore.write(1, academic);
      expect(await AcademicScheduleStore.read(2), isNull);
      expect((await AcademicScheduleStore.read(1))!.rows, academic.rows);
      final restored = CatalogCourse.fromJson(course.toJson());
      expect(restored.courseCode, 'CS1');
      expect(restored.timetablesOn(DateTime(2026, 9, 14)), isEmpty);
      expect(restored.timetables[1]!.single.lastSequence, 4);
      expect(restored.timetables[1]!.single.classroom, '教学楼101');
    },
  );
  test(
    'ambiguous same names and duplicate Tron courses are never silently bound',
    () {
      final academic = schedule(
        rows: [
          meeting(),
          meeting(code: 'CS2', cls: 'B'),
        ],
      );
      expect(
        academic
            .apply([const CatalogCourse(id: 'c', title: '计算机网络')])
            .single
            .academicMatched,
        isFalse,
      );
      expect(
        academic
            .apply([
              const CatalogCourse(id: 'c', title: '计算机网络', courseCode: 'CS2'),
            ])
            .single
            .academicMatched,
        isTrue,
      );
      expect(
        schedule()
            .apply([
              const CatalogCourse(id: '1', title: '计算机网络'),
              const CatalogCourse(id: '2', title: '计算机网络'),
            ])
            .every((c) => !c.academicMatched),
        isTrue,
      );
    },
  );
  test(
    'current pkjgList is authoritative; historical changes are not applied twice',
    () {
      final academic = schedule(
        rows: [meeting(mask: '001000')],
        changes: [
          {
            'KCDM': 'CS1',
            'BJDM': 'A',
            'YSKZC': '001000',
            'YSKXQ': '1',
            'YKSJC': '3',
            'YJSJC': '4',
            'XSKZC': '000100',
            'XSKXQ': '3',
            'XKSJC': '5',
            'XJSJC': '6',
            'XJASMC': '新教室',
          },
        ],
      );
      final c = academic.apply([
        const CatalogCourse(id: 'c', title: '计算机网络'),
      ]).single;
      expect(c.timetablesOn(DateTime(2026, 9, 21))[1]!.single.sequence, 3);
      expect(c.timetablesOn(DateTime(2026, 9, 30)), isEmpty);
    },
  );
  test(
    'invalid mask/time fail, unrelated historical changes cannot reject a current timetable',
    () {
      expect(
        () => schedule(rows: [meeting(mask: '1-8周')]),
        throwsFormatException,
      );
      expect(() => schedule(rows: [meeting(first: 19)]), throwsFormatException);
      expect(
        schedule(
          changes: [
            {'YSKZC': 'invalid history', 'XSKZC': '010'},
          ],
        ).allTables,
        isNotEmpty,
      );
    },
  );
  test(
    'window union retains gaps, exact boundaries, odd weeks and midnight dates',
    () {
      final academic = schedule(
        rows: [
          meeting(mask: '100000'),
          meeting(code: 'CS2', first: 5, last: 6, mask: '100000'),
        ],
      );
      final ranges = scheduleIntervals([
        academic.allTables,
      ], DateTime(2026, 9, 7));
      expect(ranges, hasLength(2));
      final window = DetectionWindow(intervals: ranges);
      expect(window.allows(DateTime(2026, 9, 7, 9, 39, 59)), isFalse);
      expect(window.allows(DateTime(2026, 9, 7, 9, 40)), isTrue);
      expect(window.allows(DateTime(2026, 9, 7, 12, 20)), isTrue);
      expect(window.allows(DateTime(2026, 9, 7, 13)), isFalse);
      expect(
        window.nextStart(DateTime(2026, 9, 7, 13)),
        DateTime(2026, 9, 7, 14),
      );
      expect(window.allows(DateTime(2026, 9, 14, 10)), isFalse);
      final overlapping = scheduleIntervals([
        academic.allTables,
        academic.allTables,
      ], DateTime(2026, 9, 7));
      expect(overlapping, ranges);
    },
  );
  test(
    'scheduled history final once; no Tue/Wed or off-week repeat; next meeting eligible',
    () {
      final academic = schedule();
      final tables = academic
          .apply([const CatalogCourse(id: 'c', title: '计算机网络')])
          .single
          .timetables;
      List<HistoryCandidate> plan(
        DateTime now,
        DateTime through, {
        bool changed = false,
      }) => selectHistoryCandidates(
        courseTitles: {'c': '计算机网络'},
        disks: {
          'c': CourseRollcallsSnapshot(
            courseId: 'c',
            courseTitle: '计算机网络',
            lastSuccessfulFetch: through,
            checkedThrough: through,
          ),
        },
        seenInProgressCourseIds: changed ? {'c'} : {},
        timetablesByCourse: {'c': tables},
        now: now,
        manualRefresh: true,
      );
      final close = DateTime(2026, 9, 7, 12, 20);
      expect(
        plan(close, DateTime(2026, 9, 7, 11)).single.reason,
        'scheduled_final',
      );
      for (final day in [8, 9, 14, 15]) {
        expect(plan(DateTime(2026, 9, day, 11), close), isEmpty);
      }
      expect(
        plan(DateTime(2026, 9, 21, 10), close).single.reason,
        'scheduled_window',
      );
      expect(
        plan(DateTime(2026, 9, 9, 11), close, changed: true).single.reason,
        'activity_changed',
      );
    },
  );
  test(
    'current semester selection does not use largest future published code',
    () {
      final rows = [
        {'XNXQDM': '20261'},
        {'XNXQDM': '20262'},
        {'XNXQDM': '20253'},
      ];
      expect(selectAcademicTerm(rows, DateTime(2026, 10, 27)), '20261');
      expect(selectAcademicTerm(rows, DateTime(2027, 1, 10)), '20261');
      expect(selectAcademicTerm(rows, DateTime(2027, 3, 1)), '20262');
    },
  );
  test(
    'manual binding persists by identity/term and display-only JW courses cannot enter attendance',
    () async {
      final academic = schedule(
        rows: [
          meeting(),
          meeting(code: 'CS2', cls: 'B'),
        ],
      );
      const courses = [CatalogCourse(id: 'tron', title: '不同的名称')];
      final group = academic.groups.keys.last;
      await AcademicBindings.write(1, academic.term, {'tron': group});
      expect(await AcademicBindings.read(2, academic.term), isEmpty);
      expect(await AcademicBindings.read(1, '20262'), isEmpty);
      final effective = academic.apply(
        courses,
        bindings: await AcademicBindings.read(1, academic.term),
      );
      expect(effective.single.academicGroup, group);
      final snapshot = CourseCatalogSnapshot(
        fetchedAt: DateTime.now(),
        courses: effective,
        academicOnlyCourses: academic.displayOnlyCourses(effective),
      );
      expect(snapshot.timetableCourses, hasLength(2));
      expect(snapshot.attendanceTitlesById.keys, ['tron']);
      expect(snapshot.academicOnlyCourses.single.id, startsWith('academic:'));
      await expectLater(
        AcademicBindings.write(1, academic.term, {'1': group, '2': group}),
        throwsFormatException,
      );
    },
  );
  test(
    'numeric HHmm and string clocks parse without treating lunch as a period index',
    () {
      expect(academicMinute(800), 480);
      expect(academicMinute(1010), 610);
      expect(academicMinute('08:00:00'), 480);
      expect(academicMinute('1430'), 870);
      expect(() => academicMinute(2560), throwsFormatException);
    },
  );

  test(
    'sanitized undergraduate EMAP fixture keeps published rows and numeric clocks',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/academic_undergraduate.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final parsed = AcademicSchedule.parse(
        term: '20261',
        monday: DateTime(2026, 9, 7),
        at: DateTime(2026, 10, 27),
        payload: fixture['payload'] as Map<String, dynamic>,
        clock: {
          for (final p in fixture['clock'] as List)
            academicInt(p['DM']): (
              start: academicMinute(p['KSSJ']),
              end: academicMinute(p['JSSJ']),
            ),
        },
      );
      expect(
        parsed.rows,
        hasLength((fixture['payload'] as Map)['pkjgList'].length),
      );
      expect(parsed.allTables, isNotEmpty);
      expect(parsed.rows.any((r) => r['JASMC'] == '调课后教室'), isFalse);
    },
  );
  test(
    'vacation and early publication do not shift semester anchors to current Monday',
    () {
      final rows = [
        {'XNXQDM': '20261'},
        {'XNXQDM': '20262'},
        {'XNXQDM': '20263'},
      ];
      expect(selectAcademicTerm(rows, DateTime(2027, 2, 1)), '20261');
      expect(selectAcademicTerm(rows, DateTime(2027, 2, 15)), '20262');
      expect(selectAcademicTerm(rows, DateTime(2027, 6, 14)), '20263');
      expect(
        academicMonday('20261', 1, DateTime(2027, 1, 25)),
        DateTime(2026, 9, 7),
      );
      expect(
        () => academicMonday('20271', 1, DateTime(2027, 8, 15)),
        throwsFormatException,
      );
      expect(
        academicMonday('20271', 2, DateTime(2027, 9, 14)),
        DateTime(2027, 9, 6),
      );
    },
  );
  test(
    'catalog term marker survives disk and legacy snapshots remain compatible',
    () async {
      final snapshot = CourseCatalogSnapshot(
        fetchedAt: DateTime.now(),
        academicTerm: '20261',
        courses: [],
      );
      await CourseCatalogStore.write(1, snapshot);
      expect((await CourseCatalogStore.read(1))!.academicTerm, '20261');
      final legacy = snapshot.toJson()..remove('academicTerm');
      expect(CourseCatalogSnapshot.fromJson(legacy).academicTerm, isNull);
    },
  );
}
