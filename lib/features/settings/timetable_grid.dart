import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

/// One placed course block on the week×period grid.
class TimetablePlacedBlock {
  const TimetablePlacedBlock({
    required this.course,
    required this.weekday,
    required this.block,
  });

  final CatalogCourse course;
  final int weekday;
  final SessionBlock block;
}

/// Vertical axis row: a period, or a break band (午休 / 晚休).
class TimetableAxisRow {
  const TimetableAxisRow.period({
    required this.sequence,
    required this.start,
    required this.end,
  })  : breakLabel = null,
        isBreak = false;

  const TimetableAxisRow.breakBand(this.breakLabel)
      : sequence = null,
        start = null,
        end = null,
        isBreak = true;

  final int? sequence;
  final DateTime? start;
  final DateTime? end;
  final String? breakLabel;
  final bool isBreak;
}

/// Quiet Utility–friendly course tints (readable on dark & light).
const kTimetableCourseColors = <Color>[
  Color(0xFF6B5B95),
  Color(0xFF3D6B9A),
  Color(0xFFB06A3C),
  Color(0xFF5A7A4A),
  Color(0xFF8B5A6B),
  Color(0xFF4A6B7A),
  Color(0xFF9A6B3D),
  Color(0xFF5B5B8B),
  Color(0xFF7A5A4A),
  Color(0xFF3A7A6B),
];

/// Stable color from course id.
Color timetableColorForCourseId(String id) {
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return kTimetableCourseColors[h % kTimetableCourseColors.length];
}

/// Default Mon–Fri; append Sat/Sun only when any course has slots that day.
List<int> visibleWeekdays(Iterable<CatalogCourse> courses) {
  var sat = false;
  var sun = false;
  for (final c in courses) {
    if (c.timetables.containsKey(6) && c.timetables[6]!.isNotEmpty) {
      sat = true;
    }
    if (c.timetables.containsKey(7) && c.timetables[7]!.isNotEmpty) {
      sun = true;
    }
  }
  return [
    1,
    2,
    3,
    4,
    5,
    if (sat) 6,
    if (sun) 7,
  ];
}

/// Max period index across catalog (fallback 10).
int maxTimetableSequence(Iterable<CatalogCourse> courses) {
  var max = 0;
  for (final c in courses) {
    for (final slots in c.timetables.values) {
      for (final s in slots) {
        if (s.sequence > max) max = s.sequence;
      }
    }
  }
  return max < 1 ? 10 : max;
}

/// Representative start/end per sequence from any slot in the catalog.
Map<int, ({DateTime start, DateTime end})> sequenceTimes(
  Iterable<CatalogCourse> courses,
) {
  final out = <int, ({DateTime start, DateTime end})>{};
  for (final c in courses) {
    for (final slots in c.timetables.values) {
      for (final s in slots) {
        out.putIfAbsent(
          s.sequence,
          () => (start: s.start, end: s.end),
        );
      }
    }
  }
  return out;
}

/// Period rows 1…[maxSeq], with 午休 after 4 and 晚休 after 8 when those bands apply.
List<TimetableAxisRow> buildTimetableAxisRows(
  Iterable<CatalogCourse> courses, {
  int? maxSeq,
}) {
  final max = maxSeq ?? maxTimetableSequence(courses);
  final times = sequenceTimes(courses);
  final rows = <TimetableAxisRow>[];
  for (var seq = 1; seq <= max; seq++) {
    final t = times[seq];
    if (t != null) {
      rows.add(
        TimetableAxisRow.period(sequence: seq, start: t.start, end: t.end),
      );
    } else {
      // Keep empty period slot so merged blocks align by sequence index.
      final anchor = DateTime(2000, 1, 3, 8, 0);
      rows.add(
        TimetableAxisRow.period(
          sequence: seq,
          start: anchor,
          end: anchor.add(const Duration(minutes: 45)),
        ),
      );
    }
    if (seq == 4 && max >= 5) {
      rows.add(const TimetableAxisRow.breakBand('午休'));
    }
    if (seq == 8 && max >= 9) {
      rows.add(const TimetableAxisRow.breakBand('晚休'));
    }
  }
  return rows;
}

/// Display title: course name + optional class in parentheses (one string).
String timetableCourseTitle(CatalogCourse c) {
  final name = c.title.trim().isEmpty ? '未命名课程' : c.title.trim();
  final cls = c.teachingClassName?.trim();
  if (cls == null || cls.isEmpty) return name;
  if (name.contains('($cls)') || name.contains('（$cls）')) return name;
  return '$name（$cls）';
}

/// Merge adjacent period numbers for grid display (ignores long rests).
///
/// Unlike [splitContiguousBlocks] (used by session prior), periods 2–3 stay
/// one block even when the official rest between them is ~30 minutes.
List<SessionBlock> mergeConsecutiveSequenceBlocks(List<TimetableSlot> slots) {
  if (slots.isEmpty) return const [];
  final sorted = [...slots]..sort((a, b) => a.sequence.compareTo(b.sequence));
  final out = <SessionBlock>[];
  var run = <TimetableSlot>[sorted.first];
  for (var i = 1; i < sorted.length; i++) {
    final s = sorted[i];
    final prev = run.last;
    if (s.sequence == prev.sequence + 1) {
      run.add(s);
    } else {
      out.add(
        SessionBlock(
          startSequence: run.first.sequence,
          endSequence: run.last.sequence,
          coreStart: run.first.start,
          coreEnd: run.last.end,
        ),
      );
      run = [s];
    }
  }
  out.add(
    SessionBlock(
      startSequence: run.first.sequence,
      endSequence: run.last.sequence,
      coreStart: run.first.start,
      coreEnd: run.last.end,
    ),
  );
  return out;
}

/// Flatten catalog into placed blocks (one per weekday × consecutive periods).
List<TimetablePlacedBlock> placeTimetableBlocks(
  Iterable<CatalogCourse> courses,
) {
  final out = <TimetablePlacedBlock>[];
  for (final c in courses) {
    for (final e in c.timetables.entries) {
      final blocks = mergeConsecutiveSequenceBlocks(e.value);
      for (final b in blocks) {
        out.add(
          TimetablePlacedBlock(course: c, weekday: e.key, block: b),
        );
      }
    }
  }
  return out;
}

/// Map period sequence → vertical index in [rows] (skipping break bands).
Map<int, int> sequenceToRowIndex(List<TimetableAxisRow> rows) {
  final map = <int, int>{};
  for (var i = 0; i < rows.length; i++) {
    final seq = rows[i].sequence;
    if (seq != null) map[seq] = i;
  }
  return map;
}
