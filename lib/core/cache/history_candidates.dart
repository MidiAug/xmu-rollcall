import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/course_period_clock.dart';

bool historyNeedsFullScan(Iterable<CourseRollcallsSnapshot?> snaps) =>
    !snaps.any((s) => s?.lastSuccessfulFetch != null);

class HistoryCandidate {
  const HistoryCandidate({
    required this.courseId,
    required this.courseTitle,
    required this.reason,
  });
  final String courseId;
  final String courseTitle;
  final String reason;
}

/// A weekly query hint. Inferred windows never become official course meetings.
class HistoryWindow {
  const HistoryWindow(
    this.weekday,
    this.startMinute,
    this.endMinute, [
    this.dates,
  ]);
  final Set<String>? dates;
  bool occursOn(DateTime day) =>
      dates == null || dates!.contains(TimetableSlot.dateKey(day));
  final int weekday;
  final int startMinute;
  final int endMinute;
  DateTime startOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, 0, startMinute);
  DateTime closeOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, 0, endMinute + 30);
}

/// Map observations to the nearest continuous group in the fixed period clock.
/// A half-hour margin covers in-class observations and uncertain early times.
List<HistoryWindow> inferHistoryWindows(Iterable<DateTime> observations) {
  final clock = coursePeriodClock();
  final groups = splitContiguousBlocks([
    for (final entry in clock.entries)
      TimetableSlot(
        sequence: entry.key,
        start: DateTime(2000, 1, 3, 0, entry.value.start),
        end: DateTime(2000, 1, 3, 0, entry.value.end),
      ),
  ]);
  final hints = <String, HistoryWindow>{};
  for (final raw in observations) {
    final time = raw.toLocal();
    final minute = minutesOfDay(time);
    int distance(SessionBlock b) {
      final start = minutesOfDay(b.coreStart);
      final end = minutesOfDay(b.coreEnd);
      return minute < start
          ? start - minute
          : minute > end
          ? minute - end
          : 0;
    }

    final nearest = groups.reduce((a, b) => distance(a) <= distance(b) ? a : b);
    final int start;
    final int end;
    if (distance(nearest) <= 30) {
      start = minutesOfDay(nearest.coreStart) - 30;
      end = minutesOfDay(nearest.coreEnd);
    } else {
      // Off-clock evidence still gets a conservative local two-hour hint.
      start = minute - 60;
      end = minute + 60;
    }
    final hint = HistoryWindow(
      time.weekday,
      start.clamp(0, 1439),
      end.clamp(0, 1439),
    );
    hints['${hint.weekday}/${hint.startMinute}/${hint.endMinute}'] = hint;
  }
  return hints.values.toList()..sort(
    (a, b) => (a.weekday * 1440 + a.startMinute).compareTo(
      b.weekday * 1440 + b.startMinute,
    ),
  );
}

List<HistoryWindow> _scheduledWindows(Map<int, List<TimetableSlot>> tables) => [
  for (final day in tables.entries) ...[
    for (final slot in day.value.where((s) => s.dates != null))
      HistoryWindow(
        day.key,
        minutesOfDay(slot.start) - 30,
        minutesOfDay(slot.end),
        slot.dates,
      ),
    for (final block in courseMeetingBlocks(
      day.value.where((s) => s.dates == null).toList(),
    ))
      HistoryWindow(
        day.key,
        minutesOfDay(block.coreStart) - 30,
        minutesOfDay(block.coreEnd),
      ),
  ],
];

bool _inWindow(List<HistoryWindow> windows, DateTime now) {
  // Tomorrow's early class can have its pre-class window before midnight.
  for (var offset = -1; offset <= 1; offset++) {
    final day = DateTime(now.year, now.month, now.day - offset);
    for (final w in windows) {
      if (w.weekday == day.weekday &&
          w.occursOn(day) &&
          !now.isBefore(w.startOn(day)) &&
          !now.isAfter(w.closeOn(day))) {
        return true;
      }
    }
  }
  return false;
}

bool _needsFinal(List<HistoryWindow> windows, DateTime through, DateTime now) {
  // One request covers all missed meetings, even after a long absence.
  for (var offset = 0; offset <= 210; offset++) {
    final day = DateTime(now.year, now.month, now.day - offset);
    for (final w in windows) {
      final close = w.closeOn(day);
      if (w.weekday == day.weekday &&
          w.occursOn(day) &&
          !close.isAfter(now) &&
          close.isAfter(through)) {
        return true;
      }
    }
  }
  return false;
}

/// Schedules and inferred timing gate ordinary pulls. Activity changes can
/// trigger an early sync; later queries also recover missed earlier records.
List<HistoryCandidate> selectHistoryCandidates({
  required Map<String, String> courseTitles,
  required Map<String, CourseRollcallsSnapshot?> disks,
  required Set<String> seenInProgressCourseIds,
  required Map<String, Map<int, List<TimetableSlot>>> timetablesByCourse,
  required DateTime now,
  bool includeNeverChecked = true,
  bool manualRefresh = false,
  String? requestedCourseId,
}) {
  final ranked = <({HistoryCandidate candidate, int priority})>[];
  final requested = requestedCourseId?.trim() ?? '';
  void add(String id, String reason, int priority) => ranked.add((
    candidate: HistoryCandidate(
      courseId: id,
      courseTitle: courseTitles[id] ?? '',
      reason: reason,
    ),
    priority: priority,
  ));
  if (manualRefresh && requested.isNotEmpty) {
    if (courseTitles.containsKey(requested)) add(requested, 'manual_course', 0);
    return ranked.map((r) => r.candidate).toList();
  }
  final local = now.toLocal();
  for (final id in courseTitles.keys) {
    if (seenInProgressCourseIds.contains(id)) {
      add(id, 'activity_changed', 0);
      continue;
    }
    final snap = disks[id];
    final last = snap?.lastSuccessfulFetch;
    final scheduled = _scheduledWindows(timetablesByCourse[id] ?? const {});
    final reliable = scheduled.isNotEmpty;
    if (last == null) {
      // Reliable timing is already known before the first history response.
      // Bootstrap must obey its window too; today's missed closing check is
      // allowed once, while genuinely unknown courses remain probe candidates.
      if (reliable) {
        if (_inWindow(scheduled, local)) {
          add(id, 'scheduled_window', 1);
        } else if (_needsFinal(
          scheduled,
          DateTime(local.year, local.month, local.day),
          local,
        )) {
          add(id, 'scheduled_final', 1);
        }
      } else if (includeNeverChecked) {
        add(id, 'never_checked', 4);
      }
      continue;
    }
    final windows = reliable
        ? scheduled
        : inferHistoryWindows(snap!.timingEvidence);
    final through = (snap!.checkedThrough ?? last).toLocal();
    if (_needsFinal(windows, through, local)) {
      add(
        id,
        reliable ? 'scheduled_final' : 'inferred_final',
        reliable ? 1 : 2,
      );
    } else if (_inWindow(windows, local)) {
      if (manualRefresh ||
          !snap.isFresh(CachePolicy.activeClassHistoryFreshFor, now: now)) {
        add(
          id,
          reliable ? 'scheduled_window' : 'inferred_window',
          reliable ? 1 : 2,
        );
      }
    } else if (!reliable && windows.isEmpty && manualRefresh) {
      add(id, 'unknown_probe', 3);
    }
  }
  // Stable buckets retain catalog order within each tier.
  return [
    for (var p = 0; p <= 4; p++)
      for (final row in ranked)
        if (row.priority == p) row.candidate,
  ];
}

/// True if any session block's [SessionBlock.coreEnd] falls in (t0, now].
bool coursePeriodEndedBetween(
  Map<int, List<TimetableSlot>> byDay,
  DateTime t0,
  DateTime now,
) {
  // Timetables use the local calendar even when a migrated cache stores UTC.
  t0 = t0.toLocal();
  now = now.toLocal();
  // Walk calendar days from t0.date to now.date (cap 21 days).
  var day = DateTime(t0.year, t0.month, t0.day);
  final endDay = DateTime(now.year, now.month, now.day);
  var guard = 0;
  while (!day.isAfter(endDay) && guard < 21) {
    guard++;
    final slots = byDay[day.weekday];
    if (slots != null && slots.isNotEmpty) {
      final blocks = splitContiguousBlocks(
        slots.where((s) => s.occursOn(day)).toList(),
      );
      for (final b in blocks) {
        if (!slots.any((s) => s.occursOn(day))) continue;
        final end = DateTime(
          day.year,
          day.month,
          day.day,
          b.coreEnd.hour,
          b.coreEnd.minute,
          b.coreEnd.second,
        );
        if (end.isAfter(t0) && !end.isAfter(now)) return true;
      }
    }
    day = day.add(const Duration(days: 1));
  }
  return false;
}
