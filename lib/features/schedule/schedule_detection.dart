import 'package:xmu_rollcall/features/monitor/detection_window_store.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';

List<({DateTime start, DateTime end})> scheduleIntervals(
  Iterable<Map<int, List<TimetableSlot>>> tables,
  DateTime now,
) {
  final ranges = <({DateTime start, DateTime end})>[];
  for (var offset = -1; offset <= 180; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    for (final table in tables) {
      final slots = (table[day.weekday] ?? const <TimetableSlot>[])
          .where((s) => s.occursOn(day))
          .toList();
      for (final block in courseMeetingBlocks(slots)) {
        ranges.add((
          start: DateTime(
            day.year,
            day.month,
            day.day,
            block.coreStart.hour,
            block.coreStart.minute - 30,
          ),
          end: DateTime(
            day.year,
            day.month,
            day.day,
            block.coreEnd.hour,
            block.coreEnd.minute + 30,
          ),
        ));
      }
    }
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  final union = <({DateTime start, DateTime end})>[];
  for (final range in ranges) {
    if (union.isNotEmpty && !range.start.isAfter(union.last.end)) {
      final last = union.removeLast();
      union.add((
        start: last.start,
        end: range.end.isAfter(last.end) ? range.end : last.end,
      ));
    } else {
      union.add(range);
    }
  }
  return union;
}

/// Same disk-backed planner for foreground and Android's independent isolate.
Future<DetectionWindow> readScheduleDetectionWindow(
  int? uid, {
  bool reload = false,
  DateTime? at,
  DetectionWindow? setting,
}) async {
  final daily = setting ?? await DetectionWindowStore.read(reload: reload, uid: uid);
  if (!daily.enabled) return daily;
  if (uid == null) return daily;
  final academic = await AcademicScheduleStore.read(uid, reload: reload);
  final catalog = await CourseCatalogStore.read(uid);
  final courses = <CatalogCourse>[];
  for (final c in catalog?.courses ?? <CatalogCourse>[]) {
    if (!c.isTeaching) {
      courses.add(c.withMeetings(await CourseScheduleStore.read(uid, c.id)));
    }
  }
  final effective = academic == null ? courses : academic.apply(courses);
  final tables = [
    if (academic != null) academic.allTables,
    for (final c in effective)
      if (!c.academicMatched && c.timetables.isNotEmpty) c.timetables,
  ];
  if (tables.isEmpty) {
    return DetectionWindow(
      scheduleBased: true,
      enabled: daily.enabled,
      intervals: const [],
    );
  }
  return DetectionWindow(
    enabled: daily.enabled,
    scheduleBased: true,
    startMinute: daily.startMinute,
    endMinute: daily.endMinute,
    hasSchedule: academic != null || tables.isNotEmpty,
    intervals: scheduleIntervals(tables, at ?? DateTime.now()),
  );
}
