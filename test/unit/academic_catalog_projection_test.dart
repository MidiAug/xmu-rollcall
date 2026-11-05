import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'package:xmu_rollcall/features/monitor/course_watch.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/schedule/schedule_detection.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final academic = AcademicSchedule(
    term: '20261',
    monday: DateTime(2026, 9, 7),
    fetchedAt: DateTime(2026, 10, 30),
    rows: [
      for (final course in [
        ('policy', '示例公共课（7）'),
        ('cloud', '示例计算课程'),
        ('iot', '示例导论'),
      ])
        AcademicCourseRow(
          courseId: course.$1,
          courseName: course.$2,
          weekday: 5,
          firstPeriod: 5,
          lastPeriod: 6,
          startMinute: 870,
          endMinute: 970,
          weeks: {8, 9},
        ),
    ],
  );
  final staleSlots = {
    1: [
      TimetableSlot(
        sequence: 1,
        start: DateTime(2000, 1, 3, 8),
        end: DateTime(2000, 1, 3, 9),
      ),
    ],
  };
  final raw = CourseCatalogSnapshot(
    fetchedAt: DateTime(2026, 10, 28),
    rolesResolved: true,
    courses: [
      CatalogCourse(
        id: 'policy',
        title: '示例公共课（7）',
        courseCode: '20262027119000000000101',
        timetables: staleSlots,
      ),
      CatalogCourse(
        id: 'cloud',
        title: '示例计算课程',
        courseCode: '202620271U1000000000101',
        timetables: staleSlots,
      ),
      CatalogCourse(
        id: 'iot',
        title: '示例导论',
        startDate: DateTime(2026, 9, 6),
      ),
      for (var i = 0; i < 31; i++)
        CatalogCourse(
          id: 'old-$i',
          title: i == 0 ? '示例计算课程' : '旧课程$i',
          courseCode: i.isEven ? '202520262U1000000000101' : '20252-old',
          startDate: DateTime(2026, 3, 2),
          timetables: staleSlots,
        ),
    ],
  );

  test(
    '34-course sticky catalog projects to the three current courses before matching',
    () {
      final projected = projectAcademicCatalog(raw, academic);
      expect(projected.courses.map((c) => c.id), ['policy', 'cloud', 'iot']);
      expect(projected.courses.every((c) => c.academicMatched), isTrue);
      expect(projected.attendanceTitlesById.keys, ['policy', 'cloud', 'iot']);
      expect(
        projected.courses.every((c) => c.timetables.keys.single == 5),
        isTrue,
      );
      expect(projected.courses.first.timetables[5]!.single.start.hour, 14);
      expect(raw.courses, hasLength(34));
    },
  );

  test(
    'missing academic cache never exposes old platform or supplemental times',
    () {
      final local = const CatalogCourse(id: 'local', title: '未知安排')
          .withMeetings([
            const CourseMeeting(
              weekday: 1,
              first: 1,
              last: 2,
              startMinutes: 480,
              endMinutes: 580,
            ),
          ]);
      final projected = projectAcademicCatalog(
        CourseCatalogSnapshot(
          fetchedAt: raw.fetchedAt,
          courses: [raw.courses.first, local],
        ),
        null,
        at: DateTime(2026, 10, 30),
      );
      expect(projected.timetablesByCourse, isEmpty);
      expect(projected.courses.last.localMeetings, hasLength(1));
    },
  );

  test(
    'watch and detection share academic dates while raw cached years remain intact',
    () async {
      await CourseCatalogStore.write(2, raw);
      await AcademicScheduleStore.write(2, academic);
      final courses = await readCourseWatchCourses(2);
      expect(courses.map((c) => c.id), ['policy', 'cloud', 'iot']);
      final now = DateTime(2026, 10, 30, 14, 25);
      final watch = await CourseWatch(
        1,
        2,
      ).window(completeProbe: true, at: now);
      final detection = await readScheduleDetectionWindow(2, at: now);
      expect(watch.allows(now), isTrue);
      expect(detection.allows(now), isTrue);
      expect(detection.allows(DateTime(2026, 11, 2, 8)), isFalse);
      expect((await CourseCatalogStore.read(2))!.courses, hasLength(34));
      expect(await readCourseWatchCourses(3), isEmpty);
    },
  );
}
