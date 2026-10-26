import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/course_period_clock.dart';

void main() {
  test(
    'clock covers all eleven periods and includes long breaks in meetings',
    () {
      final clock = coursePeriodClock([]);
      expect(clock.keys, List.generate(11, (i) => i + 1));
      expect(clock[1]!.start, 480);
      expect(clock[3]!.end, 655);
      expect(clock[5]!.start, 870);
      expect(clock[6]!.end, 970);
      expect(periodTimeLabel(clock[11]!.end), '21:45');
    },
  );
  test(
    'exact platform time wins; user meetings do not redefine the period clock',
    () {
      final course = CatalogCourse(
        id: 'c',
        title: '课程',
        timetables: {
          1: [
            TimetableSlot(
              sequence: 9,
              start: DateTime(2000, 1, 3, 19, 20),
              end: DateTime(2000, 1, 3, 20, 5),
            ),
          ],
        },
      );
      const local = CatalogCourse(
        id: 'local',
        title: '自填课程',
        localMeetings: [
          CourseMeeting(
            weekday: 1,
            first: 5,
            last: 7,
            startMinutes: 100,
            endMinutes: 500,
          ),
        ],
      );
      final clock = coursePeriodClock([course, local]);
      expect(clock[9], (start: 1160, end: 1205));
      expect(clock[5]!.start, 870);
    },
  );
}
