import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
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

/// Stable course identity hues, shared by light and dark surfaces.
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

  /// Contrasting same-hue text / icons on [fill].
  final Color ink;
}

/// Stable pastel tint from course id.
TimetableCourseTint timetableTintForCourseId(
  String id, {
  Brightness brightness = Brightness.light,
}) {
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final accent = kTimetableCourseAccents[h % kTimetableCourseAccents.length];
  final dark = brightness == Brightness.dark;
  final fill = Color.lerp(
    dark ? AppPalette.darkPalette.surface : AppPalette.lightPalette.surface,
    accent,
    dark ? 0.16 : 0.10,
  )!;
  final ink = Color.lerp(
    accent,
    dark ? const Color(0xFFFFFFFF) : const Color(0xFF18181B),
    dark ? 0.60 : 0.48,
  )!;
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
        if (s.lastSequence > max) max = s.lastSequence;
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
        if (s.endSequence == null) {
          out.putIfAbsent(s.sequence, () => (start: s.start, end: s.end));
        }
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
      // Keep the axis aligned, without inventing a time for missing slots.
      rows.add(TimetableAxisRow.period(sequence: seq, start: null, end: null));
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
List<SessionBlock> mergeConsecutiveSequenceBlocks(List<TimetableSlot> slots) =>
    courseMeetingBlocks(slots);

/// Flatten catalog into placed blocks (one per weekday × consecutive periods).
List<TimetablePlacedBlock> placeTimetableBlocks(
  Iterable<CatalogCourse> courses,
) {
  final out = <TimetablePlacedBlock>[];
  for (final c in courses) {
    for (final e in c.timetables.entries) {
      final blocks = mergeConsecutiveSequenceBlocks(e.value);
      for (final b in blocks) {
        final slot = e.value.where((s) => s.sequence == b.startSequence).first;
        final placedCourse = slot.classroom == null
            ? c
            : CatalogCourse(
                id: c.id,
                title: c.title,
                timetables: c.timetables,
                instructorNames: c.instructorNames,
                teachingClassName: c.teachingClassName,
                location: slot.classroom,
                roles: c.roles,
              );
        out.add(
          TimetablePlacedBlock(course: placedCourse, weekday: e.key, block: b),
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
