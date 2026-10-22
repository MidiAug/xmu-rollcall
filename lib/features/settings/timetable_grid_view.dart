import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid.dart';

/// Week × period timetable grid (shared by real catalog page + debug preview).
class TimetableGridView extends StatelessWidget {
  const TimetableGridView({super.key, required this.courses});

  final List<CatalogCourse> courses;

  static const _headerH = 32.0;
  static const _periodColW = 40.0;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final days = visibleWeekdays(courses);
    final rows = buildTimetableAxisRows(courses);
    final seqIndex = sequenceToRowIndex(rows);
    final blocks = placeTimetableBlocks(courses);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (!w.isFinite || !h.isFinite || w <= 0 || h <= 0) {
          return const SizedBox.shrink();
        }

        final breakCount = rows.where((r) => r.isBreak).length;
        final periodCount = rows.length - breakCount;
        final bodyH = (h - _headerH).clamp(1.0, h);
        final breakH = periodCount == 0
            ? 0.0
            : (bodyH / (periodCount + breakCount * 0.42) * 0.42).clamp(
                12.0,
                20.0,
              );
        final periodH = periodCount == 0
            ? bodyH
            : ((bodyH - breakH * breakCount) / periodCount).clamp(18.0, 80.0);
        final dayW = (w - _periodColW) / days.length;
        final usedBodyH = periodH * periodCount + breakH * breakCount;

        double yOfRow(int rowIndex) {
          var y = 0.0;
          for (var i = 0; i < rowIndex; i++) {
            y += rows[i].isBreak ? breakH : periodH;
          }
          return y;
        }

        final blockWidgets = <Widget>[];
        for (final b in blocks) {
          if (!days.contains(b.weekday)) continue;
          final startRow = seqIndex[b.block.startSequence];
          final endRow = seqIndex[b.block.endSequence];
          if (startRow == null || endRow == null) continue;
          final dayIdx = days.indexOf(b.weekday);
          final top = yOfRow(startRow) + 1;
          final bottom =
              yOfRow(endRow) + (rows[endRow].isBreak ? breakH : periodH) - 1;
          blockWidgets.add(
            Positioned(
              left: dayIdx * dayW + 1.5,
              width: dayW - 3,
              top: top,
              height: (bottom - top).clamp(16.0, usedBodyH),
              child: _CourseBlockChip(
                block: b,
                tint: timetableTintForCourseId(b.course.id),
                onTap: () => _showBlockDetail(context, b),
              ),
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: _headerH,
              child: Row(
                children: [
                  const SizedBox(width: _periodColW),
                  for (final d in days)
                    Expanded(
                      child: Center(
                        child: Text(
                          weekdayLabel(d),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (d == 6 || d == 7) ? p.primary : p.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: usedBodyH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _periodColW,
                    height: usedBodyH,
                    child: Column(
                      children: [
                        for (final r in rows)
                          _axisLabel(r, p, periodH: periodH, breakH: breakH),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: usedBodyH,
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              for (final r in rows)
                                Container(
                                  height: r.isBreak ? breakH : periodH,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: r.isBreak
                                        ? p.surfaceHigh.withValues(alpha: 0.5)
                                        : null,
                                    border: Border(
                                      top: BorderSide(
                                        color: p.border,
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: r.isBreak
                                      ? Text(
                                          r.breakLabel ?? '',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: p.muted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        )
                                      : null,
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              for (var i = 0; i < days.length; i++)
                                Expanded(
                                  child: Container(
                                    height: usedBodyH,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                          color: p.border,
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          ...blockWidgets,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _axisLabel(
    TimetableAxisRow r,
    AppPalette p, {
    required double periodH,
    required double breakH,
  }) {
    if (r.isBreak) return SizedBox(height: breakH);
    return SizedBox(
      height: periodH,
      width: _periodColW,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${r.sequence}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: p.ink,
            ),
          ),
          if (r.start != null && r.end != null && periodH >= 28)
            Text(
              '${formatHm(r.start!)}\n${formatHm(r.end!)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, height: 1.1, color: p.muted),
            ),
        ],
      ),
    );
  }

  void _showBlockDetail(BuildContext context, TimetablePlacedBlock b) {
    final p = AppPalette.of(context);
    final c = b.course;
    final title = timetableCourseTitle(c);

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Material(
              color: p.surface,
              borderRadius: BorderRadius.circular(AppRadii.dialog),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.schedule_outlined,
                      text:
                          '${weekdayLabel(b.weekday)} ${b.block.sectionLabel}'
                          '（${formatHm(b.block.coreStart)}-${formatHm(b.block.coreEnd)}）',
                      muted: p.muted,
                      ink: p.ink,
                    ),
                    if (c.instructorsLabel.isNotEmpty)
                      _DetailRow(
                        icon: Icons.person_outline,
                        text: c.instructorsLabel,
                        muted: p.muted,
                        ink: p.ink,
                      ),
                    if (c.location != null && c.location!.isNotEmpty)
                      _DetailRow(
                        icon: Icons.place_outlined,
                        text: c.location!,
                        muted: p.muted,
                        ink: p.ink,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.text,
    required this.muted,
    required this.ink,
  });

  final IconData icon;
  final String text;
  final Color muted;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: ink, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseBlockChip extends StatelessWidget {
  const _CourseBlockChip({
    required this.block,
    required this.tint,
    required this.onTap,
  });

  final TimetablePlacedBlock block;
  final TimetableCourseTint tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = block.course;
    final title = timetableCourseTitle(c);
    final ink = tint.ink;
    final meta = ink.withValues(alpha: 0.78);
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tint.fill,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: ink,
                  ),
                ),
              ),
              if (c.location != null && c.location!.isNotEmpty)
                Text(
                  '@${c.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 8, height: 1.1, color: meta),
                ),
              if (c.instructorNames.isNotEmpty)
                Text(
                  c.instructorNames.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 8, height: 1.1, color: meta),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
