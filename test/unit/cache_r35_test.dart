import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/core/cache/history_candidates.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CourseRollcallsStore', () {
    test('success writes lastSuccessfulFetch; failure keeps records', () async {
      final ok = await CourseRollcallsStore.writeSuccess(
        userId: 1,
        courseId: 'c1',
        courseTitle: '线性代数',
        records: const [
          CourseRollcallRecord(
            courseId: 'c1',
            courseTitle: '线性代数',
            rollcallId: '9',
            rollcallTime: null,
            typeLabel: '数字',
            signedStatus: '已签到',
            platformStatus: 'on',
          ),
        ],
        at: DateTime.utc(2026, 9, 1, 10),
      );
      expect(ok.fetchState, CourseRollcallsFetchState.hasRecords);
      expect(ok.lastSuccessfulFetch, DateTime.utc(2026, 9, 1, 10));

      final failed = await CourseRollcallsStore.writeFailure(
        userId: 1,
        courseId: 'c1',
        courseTitle: '线性代数',
        error: 'network',
        previous: ok,
      );
      expect(failed.fetchState, CourseRollcallsFetchState.failed);
      expect(failed.records.length, 1);
      expect(failed.lastSuccessfulFetch, DateTime.utc(2026, 9, 1, 10));

      final rows = CourseRollcallsStore.toHistoryRows(failed);
      expect(rows.any((r) => r.signedStatus.contains('更新失败')), isTrue);
      expect(rows.any((r) => r.rollcallId == '9'), isTrue);
    });

    test('empty success and never-checked rows', () {
      final empty = CourseRollcallsSnapshot(
        courseId: 'c',
        courseTitle: '课',
        lastSuccessfulFetch: DateTime.now(),
      );
      expect(
        CourseRollcallsStore.toHistoryRows(empty).single.signedStatus,
        contains('暂无'),
      );

      const never = CourseRollcallsSnapshot(courseId: 'c', courseTitle: '课');
      expect(
        CourseRollcallsStore.toHistoryRows(never).single.signedStatus,
        '尚未更新',
      );
    });
  });

  group('CourseCatalogStore', () {
    test('round-trips courses with timetables', () async {
      final day = DateTime(2000, 1, 3);
      final snap = CourseCatalogSnapshot(
        fetchedAt: DateTime.utc(2026, 9, 25),
        semesterId: 's1',
        courses: [
          CatalogCourse(
            id: '10',
            title: '高等数学',
            instructorNames: const ['李老师'],
            timetables: {
              1: [
                TimetableSlot(
                  sequence: 1,
                  start: DateTime(day.year, day.month, day.day, 8, 0),
                  end: DateTime(day.year, day.month, day.day, 8, 45),
                ),
              ],
            },
          ),
        ],
      );
      await CourseCatalogStore.write(42, snap);
      final back = await CourseCatalogStore.read(42);
      expect(back, isNotNull);
      expect(back!.courses.single.title, '高等数学');
      expect(back.courses.single.instructorNames, ['李老师']);
      expect(back.timetablesByCourse['10']![1]!.single.sequence, 1);
      expect(back.semesterId, 's1');
    });
  });

  group('selectHistoryCandidates', () {
    test('in-progress bypasses floor; fresh skipped; period-ended included', () {
      final now = DateTime(2026, 9, 25, 16, 0);
      final staleAt = now.subtract(const Duration(hours: 5));
      final stale = CourseRollcallsSnapshot(
        courseId: 'a',
        courseTitle: 'A',
        lastSuccessfulFetch: staleAt,
      );
      final fresh = CourseRollcallsSnapshot(
        courseId: 'b',
        courseTitle: 'B',
        lastSuccessfulFetch: now.subtract(const Duration(minutes: 30)),
      );
      final day = DateTime(2000, 1, 3);
      // Slot ends at 14:45 local on [now]'s calendar day — after staleAt, before now.
      final tables = <String, Map<int, List<TimetableSlot>>>{
        'a': {
          now.weekday: [
            TimetableSlot(
              sequence: 5,
              start: DateTime(day.year, day.month, day.day, 14, 0),
              end: DateTime(day.year, day.month, day.day, 14, 45),
            ),
          ],
        },
      };

      final candidates = selectHistoryCandidates(
        courseTitles: {'a': 'A', 'b': 'B', 'c': 'C'},
        disks: {'a': stale, 'b': fresh, 'c': null},
        seenInProgressCourseIds: {'b'},
        timetablesByCourse: tables,
        now: now,
      );

      final ids = candidates.map((e) => e.courseId).toSet();
      expect(ids.contains('b'), isTrue); // in_progress even if fresh
      expect(ids.contains('c'), isTrue); // never_checked
      expect(ids.contains('a'), isTrue); // period ended after stale fetch
      expect(
        candidates.firstWhere((e) => e.courseId == 'b').reason,
        'in_progress',
      );
      expect(
        candidates.firstWhere((e) => e.courseId == 'a').reason,
        'period_ended',
      );
    });
  });
}
