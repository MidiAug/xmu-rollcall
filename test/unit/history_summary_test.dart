import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/history/history_summary.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

CourseRollcallRecord record(
  String id,
  String status, {
  String course = 'a',
  DateTime? at,
}) => CourseRollcallRecord(
  courseId: course,
  courseTitle: course,
  rollcallId: id,
  rollcallTime: at,
  typeLabel: '数字',
  signedStatus: status,
  platformStatus: '',
);

void main() {
  test(
    'counts events, separates unknown, ignores placeholders and deduplicates per course',
    () {
      final summary = HistorySummary([
        record('-', '无签到'),
        record('1', '已签到', at: DateTime(2026, 10, 22, 8)),
        record('1', '已签到', at: DateTime(2026, 10, 22, 8)),
        record('2', '未签到', at: DateTime(2026, 10, 22, 9)),
        record('3', '未知'),
        record('1', '已签到', course: 'b'),
      ]);
      expect(summary.total, 4);
      expect(summary.count(HistoryAttendance.signed), 2);
      expect(summary.count(HistoryAttendance.unsigned), 1);
      expect(summary.count(HistoryAttendance.other), 1);
      // Two events on the same day remain separate observations.
      expect(summary.records.take(2).map((r) => r.rollcallId), ['2', '1']);
    },
  );

  test(
    'date range includes the whole local end day and excludes undated rows',
    () {
      final start = DateTime(2026, 10, 21);
      final end = DateTime(2026, 10, 22);
      bool matches(DateTime? at) =>
          historyInDateRange(record('1', '已签到', at: at), start, end);
      expect(matches(start.subtract(const Duration(milliseconds: 1))), isFalse);
      expect(matches(start), isTrue);
      expect(matches(DateTime(2026, 10, 22, 23, 59, 59, 999)), isTrue);
      expect(matches(DateTime(2026, 10, 23)), isFalse);
      expect(matches(null), isFalse);
      final local = DateTime(2026, 10, 22, 23);
      expect(matches(local.toUtc()), isTrue);
      expect(historyInDateRange(record('-', '无签到'), null, null), isTrue);
      expect(
        historyInDateRange(record('-', '无签到', at: start), start, end),
        isFalse,
      );
    },
  );
}
