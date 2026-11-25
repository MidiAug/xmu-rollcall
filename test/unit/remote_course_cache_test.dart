import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/remote_course_cache.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';

void main() {
  test(
    'clear remote snapshots across accounts while preserving user data',
    () async {
      SharedPreferences.setMockInitialValues({
        'term_start_v1_1_20261': '2026-09-07',
        'local_course_meetings_1_10': 'manual meetings',
        'saved_locations_1': 'user places',
        'grades_v1_1_1': 'grade cache',
        'lectures_v1_1_1': 'lecture cache',
        'lecture_requirement_v1_1_2': 'plan requirement cache',
        'grade_attempt_1_1': 10,
        'exams_v1_1_1_20261': 'exam cache',
        'exams_v1_1_2_20261_attempt': 10,
        'exams_v1_2_2_20262_failure': 10,
        'academic_failure_kind_2': 'request',
        'academic_attempt_2': 10,
      });
      for (final uid in [1, 2]) {
        await AcademicScheduleStore.write(
          uid,
          AcademicSchedule(
            term: '20261',
            monday: DateTime(2026, 9, 7),
            fetchedAt: DateTime(2026, 10, 29),
            rows: const [],
          ),
        );
        await JsonDiskCache.writeList('homework_todos_$uid', [
          {'id': uid},
        ]);
      }
      await clearRemoteCourseCache();
      for (final uid in [1, 2]) {
        expect(
          await AcademicScheduleStore.read(uid, useUserStart: false),
          isNull,
        );
        expect(await JsonDiskCache.readList('homework_todos_$uid'), isNull);
      }
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('term_start_v1_1_20261'), '2026-09-07');
      expect(prefs.getString('local_course_meetings_1_10'), 'manual meetings');
      expect(prefs.getString('saved_locations_1'), 'user places');
      expect(prefs.containsKey('grades_v1_1_1'), isFalse);
      expect(prefs.containsKey('lectures_v1_1_1'), isFalse);
      expect(prefs.containsKey('lecture_requirement_v1_1_2'), isFalse);
      expect(prefs.containsKey('grade_attempt_1_1'), isFalse);
      expect(prefs.containsKey('exams_v1_1_1_20261'), isFalse);
      expect(prefs.containsKey('exams_v1_1_2_20261_attempt'), isFalse);
      expect(prefs.containsKey('exams_v1_2_2_20262_failure'), isFalse);
      expect(prefs.containsKey('academic_failure_kind_2'), isFalse);
      expect(prefs.containsKey('academic_attempt_2'), isFalse);
    },
  );
}
