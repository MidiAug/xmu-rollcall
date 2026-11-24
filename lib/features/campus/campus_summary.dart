import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

/// Rendering-independent view data, also usable by a future home-screen widget.
class CampusMeeting {
  const CampusMeeting({
    required this.id,
    required this.title,
    required this.room,
    required this.start,
    required this.end,
  });
  final String id, title, room;
  final DateTime start, end;
  bool ongoing(DateTime now) => !now.isBefore(start) && now.isBefore(end);
}

class CampusCourseSummary {
  const CampusCourseSummary({
    this.current,
    this.next,
    this.afterNext,
    this.hasCoursesToday = false,
  });
  final CampusMeeting? current, next, afterNext;
  final bool hasCoursesToday;
  String? get emptyMessage => visible.isNotEmpty
      ? null
      : hasCoursesToday
      ? '今天的课程已结束'
      : '今天没有课程';
  List<CampusMeeting> get visible =>
      current != null ? [current!, ?next] : [?next, ?afterNext];
}

/// A course caption is shown only for one unambiguous academic title match.
/// Absence/ambiguity stays absent; a room or time is never inferred from a name.
CampusMeeting? selectCampusMeetingForTitle(
  AcademicSchedule schedule,
  DateTime at,
  String title,
) {
  String normalized(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  final matches = schedule.groups.values
      .where((rows) => normalized(rows.first.courseName) == normalized(title))
      .toList();
  if (matches.length != 1) return null;
  final scoped = AcademicSchedule(
    term: schedule.term,
    monday: schedule.monday,
    fetchedAt: schedule.fetchedAt,
    rows: matches.single,
  );
  final summary = selectCampusCourses(scoped, at);
  return summary.current ?? summary.next;
}

/// Only this local day. Never fills the two slots with earlier/later days.
CampusCourseSummary selectCampusCourses(
  AcademicSchedule schedule,
  DateTime at,
) {
  final now = at.toLocal();
  final meetings = <CampusMeeting>[];
  final seen = <String>{};
  for (final group in schedule.groups.entries) {
    for (final slot
        in schedule.tables(group.value)[now.weekday] ??
            const <TimetableSlot>[]) {
      if (!slot.occursOn(now)) continue;
      final start = DateTime(
        now.year,
        now.month,
        now.day,
        slot.start.hour,
        slot.start.minute,
      );
      final end = DateTime(
        now.year,
        now.month,
        now.day,
        slot.end.hour,
        slot.end.minute,
      );
      final id =
          '${group.key}/${start.toIso8601String()}/${end.toIso8601String()}/${slot.classroom}';
      if (!end.isAfter(start) || !seen.add(id)) continue;
      meetings.add(
        CampusMeeting(
          id: id,
          title: group.value.first.courseName,
          room: slot.classroom ?? '',
          start: start,
          end: end,
        ),
      );
    }
  }
  meetings.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : a.id.compareTo(b.id);
  });
  CampusMeeting? current, next, afterNext;
  for (final meeting in meetings) {
    if (current == null && meeting.ongoing(now)) current = meeting;
    if (meeting.start.isAfter(now)) {
      if (next == null) {
        next = meeting;
      } else {
        afterNext ??= meeting;
      }
    }
  }
  return CampusCourseSummary(
    hasCoursesToday: meetings.isNotEmpty,
    current: current,
    next: next,
    afterNext: afterNext,
  );
}
