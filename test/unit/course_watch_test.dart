import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/monitor/course_watch.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/platform/android_monitor_store.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';

DateTime at(int hour, int minute, [int day = 30]) =>
    DateTime(2026, 10, day, hour, minute);
TimetableSlot slot(int sequence, int hour, int minute) => TimetableSlot(
  sequence: sequence,
  start: at(hour, minute),
  end: at(hour, minute).add(const Duration(minutes: 45)),
);
final slots = [slot(1, 8, 0), slot(2, 8, 55)];
RollcallItem activity(int id, [String course = 'watch-course']) =>
    RollcallItem.fromJson({
      'rollcall_id': id,
      'course_id': course,
      'course_title': '测试课',
      'is_number': true,
      'status': 'on_call',
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'weekly scope choices merge alternating dates without artificial single periods',
    () {
      TimetableSlot dated(int sequence, String date) => TimetableSlot(
        sequence: sequence,
        start: at(8, sequence == 1 ? 0 : 55),
        end: at(sequence == 1 ? 8 : 9, sequence == 1 ? 45 : 40),
        dates: {date},
      );
      final choices = courseWatchWeeklyBlocks([
        dated(1, '2026-10-30'),
        dated(2, '2026-10-30'),
        dated(1, '2026-11-06'),
        dated(2, '2026-11-06'),
      ]);
      expect(choices.map((b) => b.id), ['1-2']);
    },
  );
  test(
    'three periods include both breaks, including a longer official break',
    () {
      final merged = [
        TimetableSlot(
          sequence: 1,
          endSequence: 3,
          start: at(8, 0),
          end: at(10, 55),
        ),
      ];
      final lesson = WatchedLesson(
        'c',
        at(0, 0),
        courseMeetingBlocks(merged).single,
        merged,
      );
      expect(lesson.ranges, [
        (start: at(7, 50), end: at(8, 0)),
        (start: at(8, 45), end: at(8, 55)),
        (start: at(9, 40), end: at(10, 10)),
        (start: at(10, 55), end: at(11, 5)),
      ]);
    },
  );
  test(
    'a 9am four-period timetable covers every actual break and its boundaries',
    () {
      final periods = [
        slot(1, 9, 0),
        slot(2, 10, 15),
        slot(3, 11, 5),
        slot(4, 12, 2),
      ];
      final lesson = WatchedLesson(
        'c',
        at(0, 0),
        courseMeetingBlocks(periods).single,
        periods,
      );
      expect(lesson.ranges, [
        (start: at(8, 50), end: at(9, 0)),
        (start: at(9, 45), end: at(10, 15)),
        (start: at(11, 0), end: at(11, 5)),
        (start: at(11, 50), end: at(12, 2)),
        (start: at(12, 47), end: at(12, 57)),
      ]);
      for (final range in lesson.ranges) {
        expect(lesson.active(range.start), isTrue);
        expect(
          lesson.active(range.end.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(lesson.active(range.end), isFalse);
      }
      expect(lesson.active(at(9, 30)), isFalse);
      expect(lesson.active(at(10, 30)), isFalse);
    },
  );
  test(
    'cached academic periods drive long-break scheduling, dates and full-probe',
    () async {
      await CourseCatalogStore.write(
        9401,
        CourseCatalogSnapshot(
          fetchedAt: at(0, 0),
          courses: [CatalogCourse(id: 'watch-course', title: '测试课')],
        ),
      );
      await AcademicScheduleStore.write(
        9401,
        AcademicSchedule(
          term: '20261',
          monday: DateTime(2026, 9, 7),
          fetchedAt: at(0, 0),
          rows: const [
            AcademicCourseRow(
              courseId: 'academic-course',
              courseName: '测试课',
              teachingClassId: 'class',
              weekday: 5,
              firstPeriod: 1,
              lastPeriod: 4,
              startMinute: 480,
              endMinute: 710,
              weeks: {8, 10},
            ),
          ],
        ),
      );
      final watch = CourseWatch(9401, 9401);
      final window = await watch.window(completeProbe: false, at: at(9, 59));
      expect(window.allows(at(9, 59)), isTrue);
      expect(window.allows(at(10, 9)), isTrue);
      expect(window.allows(at(10, 10)), isFalse);
      expect(window.nextStart(at(10, 10)), at(10, 55));
      expect(watch.select([activity(401)], at: at(10, 9)), hasLength(1));
      await watch.succeeded(activity(401));
      expect(
        (await watch.window(
          completeProbe: false,
          at: at(10, 55),
        )).allows(at(10, 55)),
        isFalse,
      );
      expect(
        (await watch.window(
          completeProbe: true,
          at: at(10, 55),
        )).allows(at(10, 55)),
        isTrue,
      );
      // The following week is absent from this course's actual teaching dates.
      final offWeek = DateTime(2026, 11, 6, 9, 59);
      expect(
        (await watch.window(completeProbe: true, at: offWeek)).allows(offWeek),
        isFalse,
      );
    },
  );
  test('an observed activity stays bound to its first dated lesson', () async {
    await CourseCatalogStore.write(
      9501,
      CourseCatalogSnapshot(
        fetchedAt: at(0, 0),
        courses: [
          CatalogCourse(
            id: 'watch-course',
            title: '测试课',
            timetables: {5: slots},
          ),
        ],
      ),
    );
    final watch = CourseWatch(9501, 9501);
    await watch.window(completeProbe: true, at: at(7, 55));
    expect(watch.select([activity(501)], at: at(7, 55)), hasLength(1));
    final nextWeek = DateTime(2026, 11, 6, 7, 55);
    await watch.window(completeProbe: true, at: nextWeek);
    expect(
      watch
          .select([activity(501), activity(502)], at: nextWeek)
          .map((i) => i.rollcallId),
      [502],
    );
    await watch.succeeded(activity(501));
    expect(
      (await watch.window(completeProbe: false, at: nextWeek)).allows(nextWeek),
      isTrue,
    );
  });
  test(
    'whole-course and weekly meeting exclusions affect real windows and stay scoped',
    () async {
      await CourseCatalogStore.write(
        9201,
        CourseCatalogSnapshot(
          fetchedAt: at(0, 0),
          courses: [
            CatalogCourse(
              id: 'watch-course',
              title: '测试课',
              timetables: {5: slots, 1: slots},
            ),
          ],
        ),
      );
      await const CourseWatchScope(
        excludedMeetings: {'watch-course/5/1-2'},
      ).save(9201, 9201);
      final watch = CourseWatch(9201, 9201);
      expect(
        (await watch.window(
          completeProbe: true,
          at: at(7, 55),
        )).allows(at(7, 55)),
        isFalse,
      );
      expect(watch.select([activity(1)], at: at(7, 55)), isEmpty);
      final monday = DateTime(2026, 11, 2, 7, 55);
      expect(
        (await watch.window(completeProbe: true, at: monday)).allows(monday),
        isTrue,
      );
      expect(
        (await CourseWatch(
          9202,
          9201,
        ).window(completeProbe: true, at: at(7, 55))).allows(at(7, 55)),
        isTrue,
      );
      await const CourseWatchScope(
        excludedCourses: {'watch-course'},
      ).save(9201, 9201);
      expect(
        (await watch.window(completeProbe: true, at: monday)).allows(monday),
        isFalse,
      );
    },
  );
  test('45 + 10 + 45 uses the actual break and excludes lecture time', () {
    final lesson = WatchedLesson(
      'c',
      at(0, 0),
      courseMeetingBlocks(slots).single,
      slots,
    );
    expect(lesson.ranges, [
      (start: at(7, 50), end: at(8, 0)),
      (start: at(8, 45), end: at(8, 55)),
      (start: at(9, 40), end: at(9, 50)),
    ]);
    for (final time in [at(7, 50), at(8, 45), at(9, 40)]) {
      expect(lesson.active(time), isTrue);
    }
    for (final time in [at(7, 49), at(8, 0), at(8, 30), at(8, 55), at(9, 50)]) {
      expect(lesson.active(time), isFalse);
    }
  });
  test('merged academic periods recover the official short break', () {
    final merged = [
      TimetableSlot(
        sequence: 1,
        endSequence: 2,
        start: at(8, 0),
        end: at(9, 40),
      ),
    ];
    final lesson = WatchedLesson(
      'c',
      at(0, 0),
      courseMeetingBlocks(merged).single,
      merged,
    );
    expect(lesson.ranges[1], (start: at(8, 45), end: at(8, 55)));
  });
  test(
    'successful lesson survives restart, with full-probe and account isolation',
    () async {
      await CourseCatalogStore.write(
        9101,
        CourseCatalogSnapshot(
          fetchedAt: at(0, 0),
          courses: [
            CatalogCourse(
              id: 'watch-course',
              title: '测试课',
              timetables: {5: slots},
            ),
          ],
        ),
      );
      final watch = CourseWatch(9101, 9101);
      final before = await watch.window(completeProbe: false, at: at(7, 50));
      expect(before.allows(at(7, 55)), isTrue);
      expect(
        watch
            .select([activity(1), activity(2, 'other')], at: at(7, 55))
            .map((i) => i.rollcallId),
        [1],
      );
      // Merely observing an activity is not a successful sign-in.
      expect(
        (await watch.window(
          completeProbe: false,
          at: at(8, 45),
        )).allows(at(8, 46)),
        isTrue,
      );
      await watch.succeeded(activity(1));
      final restored = CourseWatch(9101, 9101);
      expect(
        (await restored.window(
          completeProbe: false,
          at: at(8, 45),
        )).allows(at(8, 46)),
        isFalse,
      );
      expect(
        (await restored.window(
          completeProbe: true,
          at: at(8, 45),
        )).allows(at(8, 46)),
        isTrue,
      );
      expect(restored.select([activity(3)], at: at(8, 46)), hasLength(1));
      expect(
        (await CourseWatch(
          9102,
          9101,
        ).window(completeProbe: false, at: at(8, 45))).allows(at(8, 46)),
        isTrue,
      );
      expect(
        (await restored.window(
          completeProbe: false,
          at: at(7, 55).add(const Duration(days: 7)),
        )).allows(at(7, 55).add(const Duration(days: 7))),
        isTrue,
      );
    },
  );
  test('Android ignores desktop watch flags, including legacy saved runs', () {
    final run = AndroidMonitorRun(
      id: 'test',
      userId: 1,
      config: const MonitorConfig(courseWatch: true, completeProbe: true),
    );
    final decoded = AndroidMonitorRun.fromJson(run.toJson());
    expect(decoded.config.courseWatch, isFalse);
    expect(decoded.config.completeProbe, isFalse);
    final legacy = run.toJson()
      ..addAll({'courseWatch': true, 'completeProbe': true});
    expect(AndroidMonitorRun.fromJson(legacy).config.courseWatch, isFalse);
    final old = run.toJson()
      ..remove('courseWatch')
      ..remove('completeProbe');
    expect(AndroidMonitorRun.fromJson(old).config.courseWatch, isFalse);
    expect(AndroidMonitorRun.fromJson(old).config.completeProbe, isFalse);
  });
}
