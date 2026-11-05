import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/schedule/academic_meetings.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/course_period_clock.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid.dart';

AcademicSchedule complexSchedule() => AcademicSchedule.parse(
  term: '20251',
  monday: DateTime(2025, 9, 15),
  at: DateTime(2025, 9, 23),
  clock: coursePeriodClock(),
  payload:
      jsonDecode(File('test/fixtures/academic_complex.json').readAsStringSync())
          as Map<String, dynamic>,
);

void main() {
  test(
    'different courses alternate in a stack; true same-date conflicts keep columns',
    () {
      AcademicSchedule data(String mask) => AcademicSchedule.parse(
        term: '20261',
        monday: DateTime(2026, 9, 7),
        at: DateTime(2026, 9, 8),
        clock: coursePeriodClock(),
        payload: {
          'success': true,
          'pkjgList': [
            {
              'KCDM': 'a',
              'BJDM': 'a',
              'KCMC': '单周示例课',
              'XQ': 2,
              'KSJCDM': 3,
              'JSJCDM': 4,
              'ZCBH': '1010',
              'JASMC': 'A101',
            },
            {
              'KCDM': 'b',
              'BJDM': 'b',
              'KCMC': '双周示例课',
              'XQ': 2,
              'KSJCDM': 3,
              'JSJCDM': 4,
              'ZCBH': mask,
              'JASMC': 'A102',
            },
          ],
        },
      );
      final exclusive = placeTimetableBlocks(
        data('0101').displayOnlyCourses(const []),
      );
      expect(timetableStacks(exclusive).single, hasLength(2));
      expect(
        timetableColumns(exclusive).values.every((v) => v.count == 1),
        isTrue,
      );
      final conflict = placeTimetableBlocks(
        data('1000').displayOnlyCourses(const []),
      );
      expect(timetableStacks(conflict), hasLength(2));
      expect(
        timetableColumns(conflict).values.every((v) => v.count == 2),
        isTrue,
      );
    },
  );
  test('compact ranges, alternating weeks and irregular ranges', () {
    expect(formatTeachingWeeks(List.generate(16, (i) => i + 1)), '1-16周');
    expect(formatTeachingWeeks(List.generate(8, (i) => (i + 1) * 2)), '1-16双周');
    expect(formatTeachingWeeks(List.generate(9, (i) => i * 2 + 1)), '1-17单周');
    expect(
      formatTeachingWeeks([6, 7, 8, 9, 10, 12, 13, 14, 15, 16]),
      '6-10、12-16周',
    );
  });
  test(
    'parallel rooms merge while odd/even operating-system meetings stay distinct',
    () {
      final data = complexSchedule();
      final mining = data.groups.values.singleWhere(
        (g) => g.first.courseName == '数据挖掘示例',
      );
      final meetings = data.tables(mining)[3]!;
      expect(meetings, hasLength(2));
      final evening = meetings.singleWhere((s) => s.sequence == 9);
      expect(evening.classroom, contains('A404、A405'));
      expect(evening.weekLabel, '1-16双周');
      final os = data.groups.values.singleWhere(
        (g) => g.first.courseName == '操作系统示例',
      );
      final variants = data.tables(os)[2]!;
      expect(variants, hasLength(2));
      expect(
        variants.singleWhere((s) => s.weekLabel == '1-16双周').classroom,
        contains('101、102'),
      );
      expect(variants[0].dates!.intersection(variants[1].dates!), isEmpty);
      final blocks = placeTimetableBlocks(data.displayOnlyCourses(const []));
      final stacks = timetableStacks(blocks);
      expect(
        stacks.where((g) => g.length == 2).length,
        greaterThanOrEqualTo(3),
      );
      for (final g in stacks.where((g) => g.length > 1)) {
        final columns = timetableColumns(blocks);
        expect(columns[g.first], columns[g.last]);
      }
    },
  );
  test(
    'contiguous same-pattern periods merge but never across lunch or weeks',
    () {
      final monday = DateTime(2026, 9, 7);
      TimetableSlot slot(int seq, {String day = '2026-09-07'}) => TimetableSlot(
        sequence: seq,
        start: DateTime(2000, 1, 3, 8, seq * 50),
        end: DateTime(2000, 1, 3, 8, seq * 50 + 45),
        classroom: 'A101',
        dates: {day},
      );
      final merged = normalizeAcademicSlots([slot(1), slot(2)], monday);
      expect(merged.single.lastSequence, 2);
      expect(normalizeAcademicSlots([slot(4), slot(5)], monday), hasLength(2));
      expect(
        normalizeAcademicSlots([slot(1), slot(2, day: '2026-09-14')], monday),
        hasLength(2),
      );
    },
  );
}
