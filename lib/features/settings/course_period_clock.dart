import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

typedef PeriodTime = ({int start, int end});

/// XMU published period clock; exact platform times take precedence.
/// https://gs.xmu.edu.cn/info/1721/28561.htm
Map<int, PeriodTime> coursePeriodClock(Iterable<CatalogCourse> courses) {
  const starts = [480, 535, 610, 665, 870, 925, 1000, 1055, 1150, 1205, 1260];
  final clock = <int, PeriodTime>{
    for (var i = 0; i < starts.length; i++)
      i + 1: (start: starts[i], end: starts[i] + 45),
  };
  final seen = <int>{};
  for (final course in courses.where((c) => c.hasPlatformSchedule)) {
    for (final slots in course.timetables.values) {
      for (final slot in slots) {
        if (slot.endSequence != null || !seen.add(slot.sequence)) continue;
        clock[slot.sequence] = (
          start: minutesOfDay(slot.start),
          end: minutesOfDay(slot.end),
        );
      }
    }
  }
  return clock;
}

String periodTimeLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
