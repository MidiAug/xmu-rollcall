import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

enum HistoryAttendance { signed, unsigned, other }

HistoryAttendance historyAttendance(CourseRollcallRecord record) {
  if (record.signedStatus.contains('未签')) return HistoryAttendance.unsigned;
  if (record.signedStatus.contains('已签')) return HistoryAttendance.signed;
  return HistoryAttendance.other;
}

/// A platform rollcall is one observation. Placeholders are never attendance.
class HistorySummary {
  /// Count-only filter summaries keep source order and skip date comparisons.
  HistorySummary(Iterable<CourseRollcallRecord> source, {bool sort = true}) {
    final unique = <String, CourseRollcallRecord>{};
    for (final record in source) {
      if (!record.isPlaceholder) {
        unique['${record.courseId}/${record.rollcallId}'] = record;
      }
    }
    records = unique.values.toList();
    if (sort) {
      records.sort(
        (a, b) => (b.rollcallTime ?? DateTime(0)).compareTo(
          a.rollcallTime ?? DateTime(0),
        ),
      );
    }
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

/// Observed types from one cached course history, not a prediction of future rollcalls.
class CourseRollcallTypeCounts {
  const CourseRollcallTypeCounts({
    this.number = 0,
    this.radar = 0,
    this.qr = 0,
    this.other = 0,
  });
  final int number, radar, qr, other;
  int get total => number + radar + qr + other;
  factory CourseRollcallTypeCounts.fromRecords(
    Iterable<CourseRollcallRecord> source,
  ) {
    var number = 0, radar = 0, qr = 0, other = 0;
    for (final r in HistorySummary(source, sort: false).records) {
      if (r.typeLabel.contains('数字')) {
        number++;
      } else if (r.typeLabel.contains('雷达')) {
        radar++;
      } else if (r.typeLabel.contains('二维码')) {
        qr++;
      } else {
        other++;
      }
    }
    return CourseRollcallTypeCounts(
      number: number,
      radar: radar,
      qr: qr,
      other: other,
    );
  }
}
