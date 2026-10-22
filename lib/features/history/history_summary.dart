import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

enum HistoryAttendance { signed, unsigned, other }

HistoryAttendance historyAttendance(CourseRollcallRecord record) {
  if (record.signedStatus.contains('未签')) return HistoryAttendance.unsigned;
  if (record.signedStatus.contains('已签')) return HistoryAttendance.signed;
  return HistoryAttendance.other;
}

/// A platform rollcall is one observation. Placeholders are never attendance.
class HistorySummary {
  HistorySummary(Iterable<CourseRollcallRecord> source) {
    final unique = <String, CourseRollcallRecord>{};
    for (final record in source) {
      if (!record.isPlaceholder) {
        unique['${record.courseId}/${record.rollcallId}'] = record;
      }
    }
    records = unique.values.toList()
      ..sort(
        (a, b) => (b.rollcallTime ?? DateTime(0)).compareTo(
          a.rollcallTime ?? DateTime(0),
        ),
      );
  }

  late final List<CourseRollcallRecord> records;
  int get total => records.length;
  int count(HistoryAttendance status) =>
      records.where((r) => historyAttendance(r) == status).length;
}

bool historyInDateRange(
  CourseRollcallRecord record,
  DateTime? start,
  DateTime? end,
) {
  if (start == null && end == null) return true;
  final time = record.rollcallTime?.toLocal();
  if (time == null || record.isPlaceholder) return false;
  if (start != null &&
      time.isBefore(DateTime(start.year, start.month, start.day))) {
    return false;
  }
  return end == null ||
      time.isBefore(DateTime(end.year, end.month, end.day + 1));
}
