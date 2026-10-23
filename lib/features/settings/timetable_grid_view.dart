import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/location/course_location_setting.dart';
import 'package:xmu_rollcall/features/location/location_picker.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid.dart';

/// Week × period timetable. Keep readable row sizes; scroll instead of shrinking
/// the text to fit late periods into the viewport. Weekday headers stay visible.
class TimetableGridView extends StatelessWidget {
  const TimetableGridView({super.key, required this.courses});

  final List<CatalogCourse> courses;

  @override
  Widget build(BuildContext context) =>
      _ScrollableTimetableGrid(courses: courses);
}

class _ScrollableTimetableGrid extends StatefulWidget {
  const _ScrollableTimetableGrid({required this.courses});
  final List<CatalogCourse> courses;

  @override
  State<_ScrollableTimetableGrid> createState() =>
      _ScrollableTimetableGridState();
}

class _ScrollableTimetableGridState extends State<_ScrollableTimetableGrid> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final touch = AppDensity.isTouch(context);
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(13) / 13,
    );
    final days = visibleWeekdays(widget.courses);
    final rows = buildTimetableAxisRows(widget.courses);
    final seqIndex = sequenceToRowIndex(rows);
    final blocks = placeTimetableBlocks(widget.courses);
    final axisW = (touch ? 56.0 : 60.0) * scale;
    final headerH = (touch ? 36.0 : 44.0) * scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (!w.isFinite || !h.isFinite || w <= 0 || h <= headerH) {
          return const SizedBox.shrink();
        }
        final gridW = math.max(
          w,
          axisW + days.length * (touch ? 56 : 108) * scale,
        );
        final dayW = (gridW - axisW) / days.length;
        final breakCount = rows.where((r) => r.isBreak).length;
        final periodCount = rows.length - breakCount;
        final breakH = (touch ? 18.0 : 22.0) * scale;
        final available = (h - headerH - breakCount * breakH) / periodCount;
        final periodH = math.max(
          (touch ? 44.0 : 56.0) * scale,
          math.min(96.0 * scale, available),
        );
        final bodyH = periodH * periodCount + breakH * breakCount;

        double yOfRow(int index) {
          var y = 0.0;
          for (var i = 0; i < index; i++) {
            y += rows[i].isBreak ? breakH : periodH;
          }
          return y;
        }

        final blockWidgets = <Widget>[];
        for (final block in blocks) {
          final start = seqIndex[block.block.startSequence];
          final end = seqIndex[block.block.endSequence];
          final day = days.indexOf(block.weekday);
          if (start == null || end == null || day < 0) continue;
          final top = yOfRow(start) + 2;
          final bottom = yOfRow(end) + periodH - 2;
          blockWidgets.add(
            Positioned(
              left: day * dayW + 2,
              width: dayW - 4,
              top: top,
              height: bottom - top,
              child: _CourseBlockChip(
                key: ValueKey(
                  'course-${block.course.id}-${block.weekday}-${block.block.id}',
                ),
                block: block,
                tint: timetableTintForCourseId(
                  block.course.id,
                  brightness: Theme.of(context).brightness,
                ),
                onTap: () => _showBlockDetail(context, block),
              ),
            ),
          );
        }

        final dayGrid = SizedBox(
          width: gridW - axisW,
          height: bodyH,
          child: Stack(
            children: [
              Column(
                children: [
                  for (final row in rows)
                    Container(
                      height: row.isBreak ? breakH : periodH,
                      decoration: BoxDecoration(
                        color: row.isBreak ? p.content : null,
                        border: Border(
                          top: BorderSide(color: p.border, width: .5),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: row.isBreak
                          ? Text(
                              row.breakLabel ?? '',
                              style: Theme.of(context).textTheme.labelSmall,
                            )
                          : null,
                    ),
                ],
              ),
              Row(
                children: [
                  for (final _ in days)
                    Expanded(
                      child: Container(
                        height: bodyH,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: p.border, width: .5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              ...blockWidgets,
            ],
          ),
        );
        final body = SizedBox(
          height: bodyH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                key: const ValueKey('timetable-periods'),
                width: axisW,
                child: Column(
                  children: [
                    for (final row in rows)
                      _axisLabel(
                        context,
                        row,
                        periodH: periodH,
                        breakH: breakH,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('timetable-horizontal'),
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: dayGrid,
                ),
              ),
            ],
          ),
        );
        final weekdays = SizedBox(
          width: gridW - axisW,
          height: headerH,
          child: Row(
            children: [
              for (final day in days)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdayLabel(day),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: touch ? 12 : 13,
                        color: day >= 6 ? p.primary : p.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        return Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.group),
            side: BorderSide(color: p.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: Scrollbar(
              controller: _horizontal,
              thumbVisibility: !touch && gridW > w,
              notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
              child: Column(
                children: [
                  SizedBox(
                    key: const ValueKey('timetable-weekdays'),
                    height: headerH,
                    child: Row(
                      children: [
                        SizedBox(
                          width: axisW,
                          child: Center(
                            child: Text(
                              '节次',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _horizontal,
                            child: weekdays,
                            builder: (context, child) => ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.centerLeft,
                                minWidth: gridW - axisW,
                                maxWidth: gridW - axisW,
                                child: Transform.translate(
                                  offset: Offset(
                                    _horizontal.hasClients
                                        ? -_horizontal.offset
                                        : 0,
                                    0,
                                  ),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _vertical,
                      thumbVisibility: !touch && bodyH > h - headerH,
                      notificationPredicate: (n) =>
                          n.metrics.axis == Axis.vertical,
                      child: SingleChildScrollView(
                        key: const ValueKey('timetable-vertical'),
                        controller: _vertical,
                        child: body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _axisLabel(
    BuildContext context,
    TimetableAxisRow row, {
    required double periodH,
    required double breakH,
  }) {
    if (row.isBreak) return SizedBox(height: breakH);
    final touch = AppDensity.isTouch(context);
    return SizedBox(
      height: periodH,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${row.sequence}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (row.start != null && row.end != null) ...[
              const SizedBox(height: 2),
              Text(
                '${formatHm(row.start!)}\n${formatHm(row.end!)}',
                textAlign: TextAlign.center,
                maxLines: 2,
                softWrap: false,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: touch ? 9 : 10,
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBlockDetail(BuildContext context, TimetablePlacedBlock block) {
    final detail = _CourseDetailFlow(block: block);
    if (!AppDensity.isTouch(context)) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .40),
        builder: (_) => Dialog(
          backgroundColor: AppPalette.of(context).surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.dialog),
            side: BorderSide(color: AppPalette.of(context).border),
          ),
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: MediaQuery.sizeOf(context).height * .85,
            ),
            child: detail,
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        backgroundColor: AppPalette.of(context).surface,
        builder: (_) => detail,
      );
    }
  }
}

String? _separateClassLabel(CatalogCourse course) {
  final label = course.teachingClassName?.trim();
  if (label == null ||
      label.isEmpty ||
      course.title.contains('($label)') ||
      course.title.contains('（$label）')) {
    return null;
  }
  return label;
}

class _CourseDetailFlow extends StatefulWidget {
  const _CourseDetailFlow({required this.block});
  final TimetablePlacedBlock block;
  @override
  State<_CourseDetailFlow> createState() => _CourseDetailFlowState();
}

class _CourseDetailFlowState extends State<_CourseDetailFlow> {
  Completer<SavedLocation?>? _pending;
  String? _selectedId;
  LatLng? _initial;

  Future<SavedLocation?> _pick(String? selectedId, LatLng? initial) {
    if (_pending != null) return _pending!.future;
    final result = Completer<SavedLocation?>();
    setState(() {
      _pending = result;
      _selectedId = selectedId;
      _initial = initial;
    });
    return result.future;
  }

  void _finish(SavedLocation? location) {
    final pending = _pending;
    setState(() => _pending = null);
    pending?.complete(location);
  }

  @override
  void dispose() {
    _pending?.complete(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSize(
    key: const ValueKey('course-detail-flow'),
    duration: AppMotion.fast,
    curve: AppMotion.fastCurve,
    child: Stack(
      children: [
        ExcludeFocus(
          excluding: _pending != null,
          child: Offstage(
            offstage: _pending != null,
            child: SingleChildScrollView(
              child: _CourseDetail(block: widget.block, pickLocation: _pick),
            ),
          ),
        ),
        if (_pending != null)
          LocationPickerContent(
            title: '选择上课地点',
            selectedId: _selectedId,
            initial: _initial,
            onSelected: _finish,
            onBack: () => _finish(null),
            onClose: () => Navigator.of(context).pop(),
          ),
      ],
    ),
  );
}

class _CourseDetail extends StatelessWidget {
  const _CourseDetail({required this.block, this.pickLocation});
  final TimetablePlacedBlock block;
  final Future<SavedLocation?> Function(String?, LatLng?)? pickLocation;

  @override
  Widget build(BuildContext context) {
    final c = block.course;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  c.title.trim().isEmpty ? '未命名课程' : c.title,
                  style: text.titleLarge,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '关闭课程详情',
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
          if (_separateClassLabel(c) != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_separateClassLabel(c)!, style: text.bodySmall),
            ),
          const SizedBox(height: 20),
          _DetailRow(
            icon: Icons.schedule_outlined,
            text:
                '${weekdayLabel(block.weekday)} ${block.block.sectionLabel}  '
                '${formatHm(block.block.coreStart)}–${formatHm(block.block.coreEnd)}',
          ),
          if (c.instructorsLabel.isNotEmpty)
            _DetailRow(icon: Icons.person_outline, text: c.instructorsLabel),
          CourseLocationSetting(
            courseId: c.id,
            courseTitle: c.title,
            displayLocation: c.location,
            pickLocation: pickLocation,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseBlockChip extends StatelessWidget {
  const _CourseBlockChip({
    super.key,
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
    final touch = AppDensity.isTouch(context);
    final p = AppPalette.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final titleStyle = Theme.of(context).textTheme.titleSmall!.copyWith(
      fontSize: touch ? 11 : 13,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0,
    );
    final metaStyle = Theme.of(context).textTheme.bodySmall!.copyWith(
      fontSize: touch ? 10 : 11,
      height: 1.35,
      color: tint.ink,
    );
    final titleH = scaler.scale(titleStyle.fontSize!) * 1.4 + 2;
    final metaH = scaler.scale(metaStyle.fontSize!) * 1.35 + 2;
    final footer = c.location?.isNotEmpty == true
        ? c.location!
        : c.instructorNames.firstOrNull ?? '';

    return Semantics(
      button: true,
      label:
          '${timetableCourseTitle(c)}，${weekdayLabel(block.weekday)}，'
          '${block.block.sectionLabel}，${c.instructorsLabel}'
          '${c.location == null ? '' : '，${c.location}'}',
      child: Material(
        color: tint.fill,
        borderRadius: BorderRadius.circular(AppRadii.control),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: p.hover,
          focusColor: p.primary.withValues(alpha: .14),
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          child: ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: touch ? 6 : 10,
                vertical: touch ? 6 : 8,
              ),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final showFooter =
                      footer.isNotEmpty &&
                      bounds.maxHeight >= titleH + metaH + 6;
                  final showClass =
                      _separateClassLabel(c) != null &&
                      bounds.maxHeight >=
                          titleH * 2 + metaH * (showFooter ? 2 : 1) + 12;
                  final reserve =
                      (showFooter ? metaH + 6 : 0) +
                      (showClass ? metaH + 4 : 0);
                  final titleLines = ((bounds.maxHeight - reserve) / titleH)
                      .floor()
                      .clamp(1, 4);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                c.title.trim().isEmpty ? '未命名课程' : c.title,
                                maxLines: titleLines,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                            ),
                            if (showClass) ...[
                              const SizedBox(height: 4),
                              Text(
                                _separateClassLabel(c)!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: metaStyle,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (showFooter) ...[
                        const SizedBox(height: 6),
                        Text(
                          footer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: metaStyle,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
