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
  }) : breakLabel = null,
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

/// Accent hues for pastel course blocks (图2 轻盈风：浅底 + 同色相深字).
const kTimetableCourseAccents = <Color>[
  Color(0xFFE86A8A), // rose
  Color(0xFF8B7CF6), // lavender
  Color(0xFFF09A4A), // apricot
  Color(0xFF5BA8E0), // sky
  Color(0xFF5CB89A), // mint
  Color(0xFFD4A017), // gold
  Color(0xFFC77DCF), // orchid
  Color(0xFF6B9BD1), // soft blue
  Color(0xFFE07A5F), // coral
  Color(0xFF4DB6A0), // teal
  Color(0xFFB07CC6), // lilac
  Color(0xFF7EB56A), // leaf
  Color(0xFFE8A0B0), // blush
  Color(0xFF5C8AD6), // cornflower
  Color(0xFFD4925A), // sand
  Color(0xFF6CB5C9), // aqua
  Color(0xFFC96B8A), // raspberry
  Color(0xFF8A9AE0), // periwinkle
  Color(0xFFC9A227), // mustard
  Color(0xFF6AAB8E), // sage
];

/// Fill + ink for one course (same id → same pair).
class TimetableCourseTint {
  const TimetableCourseTint({required this.fill, required this.ink});

  /// Soft pastel block background.
  final Color fill;

  /// Darker same-hue text / icons on [fill].
  final Color ink;
}

/// Stable pastel tint from course id.
TimetableCourseTint timetableTintForCourseId(String id) {
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final accent = kTimetableCourseAccents[h % kTimetableCourseAccents.length];
  // ~18% accent into white → airy fill; ink = accent darkened for contrast.
  final fill = Color.lerp(const Color(0xFFFFFFFF), accent, 0.20)!;
  final ink = Color.lerp(accent, const Color(0xFF1A1A1A), 0.28)!;
  return TimetableCourseTint(fill: fill, ink: ink);
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
  return [1, 2, 3, 4, 5, if (sat) 6, if (sun) 7];
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
        out.putIfAbsent(s.sequence, () => (start: s.start, end: s.end));
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
        out.add(TimetablePlacedBlock(course: c, weekday: e.key, block: b));
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
