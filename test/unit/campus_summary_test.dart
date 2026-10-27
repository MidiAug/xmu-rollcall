import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/campus/campus_summary.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';

AcademicSchedule schedule({List<Map<String, dynamic>>? rows}) =>
    AcademicSchedule(
      term: '20261',
      monday: DateTime(2026, 10, 26),
      fetchedAt: DateTime(2026, 10, 28),
      rows:
          rows ??
          [
            row('old', 480, 570),
            row('current', 600, 710),
            row('next', 870, 970),
            row('later', 1000, 1100),
          ],
    );
Map<String, dynamic> row(
  String id,
  int start,
  int end, {
  String mask = '1',
  int day = 3,
}) => {
  'KCDM': id,
  'BJDM': 'A',
  'KCMC': id,
  'XQ': day,
  'KSJCDM': 1,
  'JSJCDM': 2,
  'ZCBH': mask,
  'JASMC': 'A101',
  'startMinute': start,
  'endMinute': end,
};
void main() {
  test(
    'task caption uses only one matching academic course on the actual day',
    () {
      final data = schedule();
      expect(
        selectCampusMeetingForTitle(
          data,
          DateTime(2026, 10, 28, 10, 30),
          'current',
        )?.room,
        'A101',
      );
      expect(
        selectCampusMeetingForTitle(
          data,
          DateTime(2026, 10, 29, 10, 30),
          'current',
        ),
        isNull,
      );
      expect(
        selectCampusMeetingForTitle(
          data,
          DateTime(2026, 10, 28, 10, 30),
          'unknown',
        ),
        isNull,
      );
      final ambiguous = schedule(
        rows: [
          row('x', 600, 710)..['KCMC'] = '同名课',
          row('y', 600, 710)..['KCMC'] = '同名课',
        ],
      );
      expect(
        selectCampusMeetingForTitle(
          ambiguous,
          DateTime(2026, 10, 28, 10, 30),
          '同名课',
        ),
        isNull,
      );
    },
  );
  test('only current and next; never earlier or further future classes', () {
    final summary = selectCampusCourses(
      schedule(),
      DateTime(2026, 10, 28, 10, 30),
    );
    expect(summary.visible.map((c) => c.title), ['current', 'next']);
  });
  test('between classes shows only next; after final class shows none', () {
    expect(
      selectCampusCourses(
        schedule(),
        DateTime(2026, 10, 28, 12),
      ).visible.map((c) => c.title),
      ['next'],
    );
    expect(
      selectCampusCourses(schedule(), DateTime(2026, 10, 28, 19)).visible,
      isEmpty,
    );
  });
  test(
    'start is inclusive, end exclusive, and next day cannot fill empty slots',
    () {
      expect(
        selectCampusCourses(
          schedule(),
          DateTime(2026, 10, 28, 10),
        ).current?.title,
        'current',
      );
      expect(
        selectCampusCourses(schedule(), DateTime(2026, 10, 28, 11, 50)).current,
        isNull,
      );
      expect(
        selectCampusCourses(schedule(), DateTime(2026, 10, 29, 9)).visible,
        isEmpty,
      );
    },
  );
  test(
    'actual weeks, cancelled meetings and deterministic overlapping classes',
    () {
      final data = schedule(
        rows: [
          row('z', 600, 710),
          row('a', 600, 710),
          row('offweek', 500, 800, mask: '01'),
          row('cancelled', 500, 800, mask: '0'),
          row('future', 870, 970),
        ],
      );
      final summary = selectCampusCourses(data, DateTime(2026, 10, 28, 10, 30));
      expect(summary.visible.map((c) => c.title), ['a', 'future']);
      expect(summary.visible, hasLength(2));
    },
  );
}
