import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid.dart';

void main() {
  final day = DateTime(2000, 1, 3);

  TimetableSlot slot(int seq, {int h = 8, int m = 0}) => TimetableSlot(
    sequence: seq,
    start: DateTime(day.year, day.month, day.day, h, m),
    end: DateTime(day.year, day.month, day.day, h, m + 45),
  );

  group('visibleWeekdays', () {
    test('defaults to Mon–Fri when no weekend slots', () {
      final courses = [
        CatalogCourse(
          id: '1',
          title: 'A',
          timetables: {
            1: [slot(1)],
            3: [slot(5)],
          },
        ),
      ];
      expect(visibleWeekdays(courses), [1, 2, 3, 4, 5]);
    });

    test('appends Sat/Sun only when present', () {
      final courses = [
        CatalogCourse(
          id: '1',
          title: 'A',
          timetables: {
            6: [slot(1)],
          },
        ),
        CatalogCourse(
          id: '2',
          title: 'B',
          timetables: {
            7: [slot(2)],
          },
        ),
      ];
      expect(visibleWeekdays(courses), [1, 2, 3, 4, 5, 6, 7]);
    });
  });

  group('buildTimetableAxisRows', () {
    test(
      'all eleven standard periods retain their fixed times without courses',
      () {
        final periods = buildTimetableAxisRows(
          [],
          maxSeq: 11,
        ).where((r) => !r.isBreak).toList();
        expect(periods, hasLength(11));
        expect(periods.first.start!.hour, 8);
        expect(periods[2].start!.minute, 10);
        expect(periods[4].start!.hour, 14);
        expect(periods[4].start!.minute, 30);
        expect(periods.last.end!.hour, 21);
        expect(periods.last.end!.minute, 45);
        final nonstandard = buildTimetableAxisRows([], maxSeq: 12).last;
        expect(nonstandard.start, isNull);
      },
    );
    test('inserts 午休 and 晚休 bands', () {
      final courses = [
        CatalogCourse(
          id: '1',
          title: 'A',
          timetables: {
            1: [slot(1), slot(4), slot(5), slot(8), slot(9)],
          },
        ),
      ];
      final rows = buildTimetableAxisRows(courses, maxSeq: 9);
      expect(rows.where((r) => r.breakLabel == '午休'), hasLength(1));
      expect(rows.where((r) => r.breakLabel == '晚休'), hasLength(1));
      final lunchIdx = rows.indexWhere((r) => r.breakLabel == '午休');
      expect(rows[lunchIdx - 1].sequence, 4);
      expect(rows[lunchIdx + 1].sequence, 5);
    });
  });

  test('course colors remain stable and text has contrast in both themes', () {
    for (final brightness in Brightness.values) {
      for (var i = 0; i < 100; i++) {
        final tint = timetableTintForCourseId('$i', brightness: brightness);
        final again = timetableTintForCourseId('$i', brightness: brightness);
        expect(tint.fill, again.fill);
        final a = tint.fill.computeLuminance();
        final b = tint.ink.computeLuminance();
        final contrast = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
    }
  });

  group('placeTimetableBlocks', () {
    test('merges contiguous short-break slots', () {
      final courses = [
        CatalogCourse(
          id: '1',
          title: 'A',
          instructorNames: const ['张三'],
          timetables: {
            2: [
              slot(1, h: 8, m: 0),
              TimetableSlot(
                sequence: 2,
                start: DateTime(day.year, day.month, day.day, 8, 55),
                end: DateTime(day.year, day.month, day.day, 9, 40),
              ),
            ],
          },
        ),
      ];
      final blocks = placeTimetableBlocks(courses);
      expect(blocks, hasLength(1));
      expect(blocks.single.block.startSequence, 1);
      expect(blocks.single.block.endSequence, 2);
      expect(blocks.single.course.instructorNames, ['张三']);
    });

    test('merges periods 2–3 across long rest (display)', () {
      final courses = [
        CatalogCourse(
          id: 'ml',
          title: '机器学习',
          teachingClassName: '信息1班',
          timetables: {
            4: [
              TimetableSlot(
                sequence: 2,
                start: DateTime(day.year, day.month, day.day, 8, 55),
                end: DateTime(day.year, day.month, day.day, 9, 40),
              ),
              TimetableSlot(
                sequence: 3,
                start: DateTime(day.year, day.month, day.day, 10, 10),
                end: DateTime(day.year, day.month, day.day, 10, 55),
              ),
            ],
          },
        ),
      ];
      final blocks = placeTimetableBlocks(courses);
      expect(blocks, hasLength(1));
      expect(blocks.single.block.startSequence, 2);
      expect(blocks.single.block.endSequence, 3);
      expect(timetableCourseTitle(courses.single), '机器学习（信息1班）');
    });
  });

  group('CatalogCourse json', () {
    test('round-trips instructors and class name', () {
      final c = CatalogCourse(
        id: '9',
        title: '机器学习',
        instructorNames: const ['王程'],
        teachingClassName: '信息1班',
        location: '西部2号楼',
        timetables: {
          5: [slot(2)],
        },
      );
      final back = CatalogCourse.fromJson(c.toJson());
      expect(back.instructorNames, ['王程']);
      expect(back.teachingClassName, '信息1班');
      expect(back.location, '西部2号楼');
    });
  });
}
