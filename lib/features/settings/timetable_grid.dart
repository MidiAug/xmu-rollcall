import 'package:xmu_rollcall/features/settings/course_period_clock.dart';
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
    this.weekLabel,
    this.dates,
  });

  final CatalogCourse course;
  final int weekday;
  final SessionBlock block;
  final String? weekLabel;
  final Set<String>? dates;
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
const kTimetableCourseAccents = AppCourseColors.accents;

/// Fill + ink for one course (same id → same pair).
class TimetableCourseTint {
  const TimetableCourseTint({
    required this.fill,
    required this.ink,
    required this.accent,
    required this.rim,
  });
  final Color accent, rim;

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
    dark ? AppPalette.darkPalette.ink : AppPalette.lightPalette.ink,
    dark ? 0.60 : 0.48,
  )!;
  return TimetableCourseTint(
    fill: fill,
    ink: ink,
    accent: Color.lerp(accent, ink, .65)!,
    rim: Color.lerp(fill, ink, dark ? .35 : .18)!,
  );
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

/// The fixed period clock, independent of which courses happen to be present.
Map<int, ({DateTime start, DateTime end})> sequenceTimes() => {
  for (final entry in coursePeriodClock().entries)
    entry.key: (
      start: DateTime(
        2000,
        1,
        3,
        entry.value.start ~/ 60,
        entry.value.start % 60,
      ),
      end: DateTime(2000, 1, 3, entry.value.end ~/ 60, entry.value.end % 60),
    ),
};

/// Period rows 1…[maxSeq], with 午休 after 4 and 晚休 after 8 when those bands apply.
List<TimetableAxisRow> buildTimetableAxisRows(
  Iterable<CatalogCourse> courses, {
  int? maxSeq,
}) {
  final max = maxSeq ?? maxTimetableSequence(courses);
  final times = sequenceTimes();
  final rows = <TimetableAxisRow>[];
  for (var seq = 1; seq <= max; seq++) {
    final t = times[seq];
    if (t != null) {
      rows.add(
        TimetableAxisRow.period(sequence: seq, start: t.start, end: t.end),
      );
    } else {
      // Nonstandard periods outside the fixed clock keep an empty time label.
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
      final meetings = [
        for (final slot in e.value.where((s) => s.dates != null))
          (
            slot: slot,
            block: SessionBlock(
              startSequence: slot.sequence,
              endSequence: slot.lastSequence,
              coreStart: slot.start,
              coreEnd: slot.end,
            ),
          ),
        for (final block in mergeConsecutiveSequenceBlocks(
          e.value.where((s) => s.dates == null).toList(),
        ))
          (
            slot: e.value.firstWhere(
              (s) => s.dates == null && s.sequence == block.startSequence,
            ),
            block: block,
          ),
      ];
      for (final meeting in meetings) {
        final b = meeting.block;
        final slot = meeting.slot;
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
          TimetablePlacedBlock(
            course: placedCourse,
            weekday: e.key,
            block: b,
            weekLabel: slot.weekLabel,
            dates: slot.dates,
          ),
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

/// Date-disjoint variants in the same period use one stack. True same-date
/// conflicts are separate groups and are still assigned distinct columns.
List<List<TimetablePlacedBlock>> timetableStacks(
  List<TimetablePlacedBlock> blocks,
) {
  final groups = <List<TimetablePlacedBlock>>[];
  for (final block in blocks) {
    final target = groups
        .where(
          (g) => g.every(
            (other) =>
                other.weekday == block.weekday &&
                other.block.id == block.block.id &&
                other.dates != null &&
                block.dates != null &&
                other.dates!.intersection(block.dates!).isEmpty,
          ),
        )
        .firstOrNull;
    if (target == null) {
      groups.add([block]);
    } else {
      target.add(block);
    }
  }
  return groups;
}

Map<TimetablePlacedBlock, ({int column, int count})> timetableColumns(
  List<TimetablePlacedBlock> blocks,
) {
  final result = <TimetablePlacedBlock, ({int column, int count})>{};
  final stacks = timetableStacks(blocks);
  for (final day in blocks.map((b) => b.weekday).toSet()) {
    final sorted = stacks.where((g) => g.first.weekday == day).toList()
      ..sort(
        (a, b) =>
            a.first.block.startSequence.compareTo(b.first.block.startSequence),
      );
    final group = <List<TimetablePlacedBlock>>[];
    var end = 0;
    void flush() {
      final ends = <int>[];
      final assignments = <List<TimetablePlacedBlock>, int>{};
      for (final stack in group) {
        final b = stack.first;
        var column = ends.indexWhere((e) => e < b.block.startSequence);
        if (column == -1) {
          column = ends.length;
          ends.add(0);
        }
        ends[column] = b.block.endSequence;
        assignments[stack] = column;
      }
      for (final stack in group) {
        for (final block in stack) {
          result[block] = (column: assignments[stack]!, count: ends.length);
        }
      }
      group.clear();
    }

    for (final stack in sorted) {
      final b = stack.first;
      if (group.isNotEmpty && b.block.startSequence > end) {
        flush();
        end = 0;
      }
      group.add(stack);
      if (b.block.endSequence > end) end = b.block.endSequence;
    }
    flush();
  }
  return result;
}
