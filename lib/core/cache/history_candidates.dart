import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

/// True when no course has ever been successfully fetched — cold / empty cache.
/// Appear + pull then scan all courses (capped); otherwise use [selectHistoryCandidates].
bool historyNeedsFullScan(Iterable<CourseRollcallsSnapshot?> snaps) {
  for (final s in snaps) {
    if (s?.lastSuccessfulFetch != null) return false;
  }
  return true;
}

/// One course considered for incremental history refresh (R-35 §3.3).
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

/// Pure: pick which courses to re-fetch between [t0] windows and [now].
///
/// - [seenInProgressCourseIds]: bypass 2h floor
/// - [timetablesByCourse]: weekday → slots; only drives "period ended" signal
/// - Never does a clock-based full scan of all courses
List<HistoryCandidate> selectHistoryCandidates({
  required Map<String, String> courseTitles,
  required Map<String, CourseRollcallsSnapshot?> disks,
  required Set<String> seenInProgressCourseIds,
  required Map<String, Map<int, List<TimetableSlot>>> timetablesByCourse,
  required DateTime now,
  Duration floor = CachePolicy.enterSwrFreshFor,
  bool includeNeverChecked = true,
}) {
  final out = <HistoryCandidate>[];
  final seen = <String>{};

  void add(String id, String reason) {
    if (id.isEmpty || seen.contains(id)) return;
    seen.add(id);
    out.add(
      HistoryCandidate(
        courseId: id,
        courseTitle: courseTitles[id] ?? disks[id]?.courseTitle ?? '',
        reason: reason,
      ),
    );
  }

  for (final id in seenInProgressCourseIds) {
    add(id, 'in_progress');
  }

  for (final id in courseTitles.keys) {
    if (seen.contains(id)) continue;
    final snap = disks[id];
    final last = snap?.lastSuccessfulFetch;
    if (last == null) {
      if (includeNeverChecked) add(id, 'never_checked');
      continue;
    }
    if (snap!.isFresh(floor, now: now)) continue;

    final tables = timetablesByCourse[id];
    if (tables == null || tables.isEmpty) {
      // No timetable: still eligible once floor elapsed (progressive).
      add(id, 'stale_no_timetable');
      continue;
    }

    if (_periodEndedBetween(tables, last, now)) {
      add(id, 'period_ended');
    }
  }

  return out;
}

/// True if any session block's [SessionBlock.coreEnd] falls in (t0, now].
bool _periodEndedBetween(
  Map<int, List<TimetableSlot>> byDay,
  DateTime t0,
  DateTime now,
) {
  // Walk calendar days from t0.date to now.date (cap 21 days).
  var day = DateTime(t0.year, t0.month, t0.day);
  final endDay = DateTime(now.year, now.month, now.day);
  var guard = 0;
  while (!day.isAfter(endDay) && guard < 21) {
    guard++;
    final slots = byDay[day.weekday];
    if (slots != null && slots.isNotEmpty) {
      final blocks = splitContiguousBlocks(slots);
      for (final b in blocks) {
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
