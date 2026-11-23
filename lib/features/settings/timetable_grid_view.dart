import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/location/course_location_setting.dart';
import 'package:xmu_rollcall/features/location/course_meeting.dart';
import 'package:xmu_rollcall/features/location/campus_map.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/place_matching.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/location/location_picker.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid.dart';

/// Week × period timetable. Keep readable row sizes; scroll instead of shrinking
/// the text to fit late periods into the viewport. Weekday headers stay visible.
class TimetableGridView extends StatelessWidget {
  const TimetableGridView({
    super.key,
    required this.courses,
    this.assistUserId,
    this.referenceDate,
    this.showDates = false,
  });
  final int? assistUserId;
  final DateTime? referenceDate;
  final bool showDates;

  final List<CatalogCourse> courses;

  @override
  Widget build(BuildContext context) => _ScrollableTimetableGrid(
    courses: courses,
    assistUserId: assistUserId,
    referenceDate: referenceDate,
    showDates: showDates,
  );
}

class _ScrollableTimetableGrid extends StatefulWidget {
  const _ScrollableTimetableGrid({
    required this.courses,
    this.assistUserId,
    this.referenceDate,
    required this.showDates,
  });
  final int? assistUserId;
  final List<CatalogCourse> courses;
  final DateTime? referenceDate;
  final bool showDates;

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
    final stacks = timetableStacks(blocks);
    final hasStack = stacks.any((variants) => variants.length > 1);
    final columns = timetableColumns(blocks);
    final maxColumns = columns.values.fold(1, (n, v) => math.max(n, v.count));
    final axisW = (touch ? 56.0 : 60.0) * scale;
    // Switching the displayed range must not shift the timetable's first row.
    // Reserve the date line even when semester mode omits specific dates.
    final headerH = (touch ? 48.0 : 52.0) * scale;
    final reference = widget.referenceDate ?? DateTime.now();
    final monday = DateTime(
      reference.year,
      reference.month,
      reference.day - reference.weekday + 1,
    );
    final today = TimetableSlot.dateKey(DateTime.now());
    DateTime dateOf(int day) => monday.add(Duration(days: day - 1));
    bool isToday(int day) =>
        widget.showDates && TimetableSlot.dateKey(dateOf(day)) == today;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (!w.isFinite || !h.isFinite || w <= 0 || h <= headerH) {
          return const SizedBox.shrink();
        }
        final gridW = math.max(
          w,
          // A stacked cell must fit the 44px touch action and a readable title.
          // Keep horizontal scrolling rather than shrinking either target.
          axisW +
              days.length *
                  (touch && !hasStack ? 56 : 108) *
                  scale *
                  maxColumns,
        );
        final dayW = (gridW - axisW) / days.length;
        final breakCount = rows.where((r) => r.isBreak).length;
        final periodCount = rows.length - breakCount;
        final breakH = (touch ? 18.0 : 22.0) * scale;
        final available = (h - headerH - breakCount * breakH) / periodCount;
        final periodH = math.max(
          (touch ? (hasStack ? 48.0 : 44.0) : 56.0) * scale,
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
        for (final variants in stacks) {
          final block = variants.first;
          final start = seqIndex[block.block.startSequence];
          final end = seqIndex[block.block.endSequence];
          final day = days.indexOf(block.weekday);
          if (start == null || end == null || day < 0) continue;
          final top = yOfRow(start) + 2;
          final bottom = yOfRow(end) + periodH - 2;
          blockWidgets.add(
            Positioned(
              left:
                  day * dayW +
                  columns[block]!.column * dayW / columns[block]!.count +
                  2,
              width: dayW / columns[block]!.count - 4,
              top: top,
              height: bottom - top,
              child: _TimetableStack(
                key: ValueKey(
                  'stack-${block.weekday}-${block.block.id}-${variants.map((b) => b.course.id).join('-')}',
                ),
                variants: variants,
                at: reference,
                onOpen: (b) => _showBlockDetail(context, b),
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
                          top: BorderSide(color: p.divider, width: .5),
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
                  for (final day in days)
                    Expanded(
                      child: Container(
                        height: bodyH,
                        decoration: BoxDecoration(
                          color: isToday(day)
                              ? p.dataAccent.withValues(alpha: .025)
                              : null,
                          border: Border(
                            left: BorderSide(color: p.divider, width: .5),
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
                  child: DecoratedBox(
                    key: ValueKey('timetable-day-$day'),
                    decoration: const BoxDecoration(),
                    child: Center(
                      child: _TimetableDayHeading(
                        day: day,
                        date: widget.showDates ? dateOf(day) : null,
                        isToday: isToday(day),
                        inline: dayW >= 116 * scale,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: double.infinity,
            // Sparse weeks should end at the last drawn row rather than leave
            // a blank framed area below the grid. Long weeks still scroll.
            height: math.min(h, headerH + bodyH),
            child: Panel(
              key: const ValueKey('timetable-surface'),
              padding: EdgeInsets.zero,
              lifted: true,
              outlined: true,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: Scrollbar(
                  controller: _horizontal,
                  thumbVisibility: !touch && gridW > w,
                  notificationPredicate: (n) =>
                      n.metrics.axis == Axis.horizontal,
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
    final detail = _CourseDetailFlow(
      block: block,
      assistUserId: widget.assistUserId,
    );
    if (!AppDensity.isTouch(context)) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .40),
        builder: (_) => AppDialogFrame(
          maxWidth: 440,
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
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => AppSheetFrame(
          padding: const EdgeInsets.only(top: 12),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    (MediaQuery.sizeOf(sheetContext).height -
                        MediaQuery.viewInsetsOf(sheetContext).bottom) *
                    .8,
              ),
              child: detail,
            ),
          ),
        ),
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

class _CourseDetailFlow extends ConsumerStatefulWidget {
  const _CourseDetailFlow({required this.block, this.assistUserId});
  final int? assistUserId;
  final TimetablePlacedBlock block;
  @override
  ConsumerState<_CourseDetailFlow> createState() => _CourseDetailFlowState();
}

class _CourseDetailFlowState extends ConsumerState<_CourseDetailFlow> {
  bool _map = false;
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
  Widget build(BuildContext context) {
    final room = widget.block.course.location ?? '';
    final userId =
        widget.assistUserId == ref.watch(selectedRollcallAccountProvider)
        ? null
        : widget.assistUserId ?? ref.watch(authControllerProvider).profile?.id;
    final match = matchCoursePlace(
      room,
      ref.watch(ref.watch(savedLocationsForUserProvider(userId))),
    );
    final point = match == null
        ? null
        : LatLng(match.latitude, match.longitude);
    final mapView = SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                AppIconButton(
                  tooltip: '返回课程',
                  onPressed: () => setState(() => _map = false),
                  icon: const Icon(AppIcons.back, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        room.isEmpty ? '上课地点' : room,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cardTitle,
                      ),
                      if (room.isNotEmpty)
                        Text(
                          '上课地点',
                          style: AppTypography.caption.copyWith(
                            color: AppPalette.of(context).muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const AppSheetCloseButton(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _map
                  ? CampusMap(
                      zoom: 17,
                      center:
                          point ??
                          (campusInName(room) ?? Campus.xiangan).center,
                      point: point,
                      places: const [],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
    return PopScope(
      canPop: !_map,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _map) setState(() => _map = false);
      },
      child: SizedBox(
        key: const ValueKey('course-detail-flow'),
        child: Stack(
          children: [
            Offstage(
              offstage: _pending != null,
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 240),
                reverseDuration: const Duration(milliseconds: 240),
                sizeCurve: Curves.easeInOutCubic,
                crossFadeState: _map
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: SingleChildScrollView(
                  child: _CourseDetail(
                    block: widget.block,
                    pickLocation: _pick,
                    onMap: () => setState(() => _map = true),
                    assistUserId: widget.assistUserId,
                  ),
                ),
                secondChild: mapView,
              ),
            ),
            if (_pending != null)
              LocationPickerContent(
                title: '选择上课地点',
                userId: userId,
                selectedId: _selectedId,
                initial: _initial,
                onSelected: _finish,
                onBack: () => _finish(null),
                onClose: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

class _CourseDetail extends StatelessWidget {
  const _CourseDetail({
    required this.block,
    this.pickLocation,
    this.onMap,
    this.assistUserId,
  });
  final int? assistUserId;
  final VoidCallback? onMap;
  final TimetablePlacedBlock block;
  final Future<SavedLocation?> Function(String?, LatLng?)? pickLocation;

  @override
  Widget build(BuildContext context) {
    final c = block.course;
    final p = AppPalette.of(context);
    final hasLocation = c.location?.isNotEmpty == true;
    final canOpenMap = hasLocation && onMap != null;
    Widget value(String label, String value) => SettingsRow(
      title: label,
      trailing: Expanded(
        child: SelectableText(
          value,
          textAlign: TextAlign.end,
          style: AppTypography.body.copyWith(
            color: p.ink,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '课程详情',
                  style: AppTypography.sectionTitle.copyWith(color: p.ink),
                ),
              ),
              const AppSheetCloseButton(
                tooltip: '关闭课程详情',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(
            c.title.trim().isEmpty ? '未命名课程' : c.title,
            style: AppTypography.cardTitle.copyWith(
              color: p.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_separateClassLabel(c) != null) ...[
            const SizedBox(height: 6),
            Text(
              _separateClassLabel(c)!,
              style: AppTypography.body.copyWith(color: p.muted),
            ),
          ],
          const SizedBox(height: 20),
          SettingsSection(
            inset: true,
            padTop: false,
            hasLeading: false,
            children: [
              if (c.instructorsLabel.isNotEmpty)
                value('教师', c.instructorsLabel),
              SettingsRow(
                key: const ValueKey('course-location-map-link'),
                title: '地点',
                onTap: canOpenMap ? onMap : null,
                trailing: Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          hasLocation ? c.location! : '教务未提供教室',
                          textAlign: TextAlign.end,
                          style: AppTypography.body.copyWith(
                            color: canOpenMap
                                ? p.primary
                                : hasLocation
                                ? p.ink
                                : p.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (canOpenMap) ...[
                        const SizedBox(width: 4),
                        Icon(AppIcons.right, size: 16, color: p.primary),
                      ],
                    ],
                  ),
                ),
              ),
              value(
                '上课时间',
                '${weekdayLabel(block.weekday)} ${block.block.sectionLabel}\n${formatHm(block.block.coreStart)}–${formatHm(block.block.coreEnd)}',
              ),
              if (block.weekLabel != null) value('教学周', block.weekLabel!),
            ],
          ),
          if (!c.id.startsWith('academic:')) ...[
            const SizedBox(height: 20),
            Text('签到地点', style: AppTypography.caption.copyWith(color: p.muted)),
            const SizedBox(height: 6),
            CourseLocationSetting(
              courseId: c.id,
              courseTitle: c.title,
              displayLocation: c.location,
              pickLocation: pickLocation,
              assistUserId: assistUserId,
              meetingKey: courseMeetingKey(block.weekday, block.block),
              meetings: courseMeetingLabels(c),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimetableStack extends StatefulWidget {
  const _TimetableStack({
    super.key,
    required this.variants,
    required this.at,
    required this.onOpen,
  });
  final List<TimetablePlacedBlock> variants;
  final DateTime at;
  final ValueChanged<TimetablePlacedBlock> onOpen;
  @override
  State<_TimetableStack> createState() => _TimetableStackState();
}

class _TimetableStackState extends State<_TimetableStack> {
  int? _selected;
  bool current(TimetablePlacedBlock b) {
    final monday = DateTime(
      widget.at.year,
      widget.at.month,
      widget.at.day - widget.at.weekday + 1,
    );
    return b.dates == null ||
        b.dates!.contains(
          TimetableSlot.dateKey(monday.add(Duration(days: b.weekday - 1))),
        );
  }

  @override
  void didUpdateWidget(covariant _TimetableStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (TimetableSlot.dateKey(oldWidget.at) !=
            TimetableSlot.dateKey(widget.at) ||
        oldWidget.variants.length != widget.variants.length) {
      _selected = null;
    }
  }

  Future<void> _showVariants(BuildContext context) async {
    final all = widget.variants;
    final heading =
        '${weekdayLabel(all.first.weekday)} ${all.first.block.sectionLabel}';
    Widget contents(BuildContext sheetContext) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('同一时段的课程', style: AppTypography.cardTitle)),
              const AppSheetCloseButton(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            heading,
            style: AppTypography.body.copyWith(
              color: AppPalette.of(sheetContext).muted,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              child: SettingsSection(
                inset: true,
                padTop: false,
                hasLeading: true,
                children: [
                  for (final b in all)
                    SettingsRow(
                      leading: Container(
                        width: 3,
                        height: 40,
                        decoration: BoxDecoration(
                          color: timetableTintForCourseId(
                            b.course.id,
                            brightness: Theme.of(context).brightness,
                          ).accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      title: b.course.title,
                      subtitle: b.course.location,
                      trailing: Icon(
                        AppIcons.right,
                        color: AppPalette.of(context).muted,
                        size: 18,
                      ),
                      onTap: () => Navigator.pop(sheetContext, b),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    final TimetablePlacedBlock? chosen;
    if (AppDensity.isTouch(context)) {
      chosen = await showModalBottomSheet<TimetablePlacedBlock>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => AppSheetFrame(
          padding: const EdgeInsets.only(top: 12),
          child: contents(sheetContext),
        ),
      );
    } else {
      chosen = await showDialog<TimetablePlacedBlock>(
        context: context,
        builder: (dialogContext) => AppDialogFrame(
          maxWidth: 440,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(dialogContext).height * .85,
            ),
            child: contents(dialogContext),
          ),
        ),
      );
    }
    if (mounted && chosen != null) widget.onOpen(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.variants;
    final index =
        _selected ??
        (all.indexWhere(current) < 0 ? 0 : all.indexWhere(current));
    final block = all[index % all.length];
    final multiple = all.length > 1;
    final p = AppPalette.of(context);
    final controlExtent = AppDensity.isTouch(context) ? 44.0 : 32.0;
    return Stack(
      children: [
        if (multiple)
          Positioned.fill(
            left: 7,
            top: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: timetableTintForCourseId(
                  all[(index + 1) % all.length].course.id,
                  brightness: Theme.of(context).brightness,
                ).fill,
                border: Border.all(color: p.primary.withValues(alpha: .25)),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
            ),
          ),
        Positioned.fill(
          right: multiple ? 7 : 0,
          bottom: multiple ? 7 : 0,
          child: _CourseBlockChip(
            key: ValueKey(
              'course-${block.course.id}-${block.weekday}-${block.block.id}${block.weekLabel == null ? '' : '-${block.weekLabel}-$index'}',
            ),
            block: block,
            controlInset: multiple ? controlExtent : 0,
            tint: timetableTintForCourseId(
              block.course.id,
              brightness: Theme.of(context).brightness,
            ),
            onTap: () =>
                multiple ? _showVariants(context) : widget.onOpen(block),
          ),
        ),
        if (multiple)
          Positioned(
            top: 0,
            right: 0,
            child: AppIconButton(
              tooltip: '切换课次（${index + 1}/${all.length}）',
              extent: controlExtent,
              padding: EdgeInsets.zero,
              onPressed: () =>
                  setState(() => _selected = (index + 1) % all.length),
              icon: Icon(AppIcons.swap, size: 15, color: p.primary),
            ),
          ),
      ],
    );
  }
}

class _CourseBlockChip extends StatelessWidget {
  const _CourseBlockChip({
    super.key,
    required this.block,
    required this.tint,
    required this.onTap,
    this.controlInset = 0,
  });
  final TimetablePlacedBlock block;
  final TimetableCourseTint tint;
  final VoidCallback onTap;
  final double controlInset;

  @override
  Widget build(BuildContext context) {
    final c = block.course;
    final touch = AppDensity.isTouch(context);
    final p = AppPalette.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final titleStyle = Theme.of(context).textTheme.titleSmall!.copyWith(
      fontSize: touch ? 12 : 14,
      fontWeight: FontWeight.w600,
      color: tint.ink,
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
    final week = block.weekLabel;
    final compact = block.block.startSequence == block.block.endSequence;
    final footerGap = compact ? 2.0 : 6.0;
    final footer = c.location?.isNotEmpty == true ? c.location! : '';

    return Semantics(
      button: true,
      label:
          '${timetableCourseTitle(c)}，${weekdayLabel(block.weekday)}，'
          '${block.block.sectionLabel}，${c.instructorsLabel}'
          '${c.location == null ? '' : '，${c.location}'}',
      child: AppHoverSurface(
        backgroundColor: tint.fill,
        hoverColor: Color.alphaBlend(p.hoverOverlay, tint.fill),
        pressedColor: Color.lerp(tint.fill, p.ink, p.isDark ? .10 : .08),
        borderRadius: BorderRadius.circular(AppRadii.control),
        outlined: true,
        borderColor: tint.rim,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!touch)
                Positioned(
                  left: 6,
                  top: 10,
                  bottom: 10,
                  width: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tint.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  touch ? 6 : 15,
                  compact ? (touch ? 2 : 4) : (touch ? 6 : 8),
                  touch ? 6 : 10,
                  compact ? (touch ? 2 : 4) : (touch ? 6 : 8),
                ),
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final showFooter =
                        footer.isNotEmpty &&
                        bounds.maxHeight >= titleH + metaH + (compact ? 0 : 6);
                    final showClass =
                        _separateClassLabel(c) != null &&
                        bounds.maxHeight >=
                            titleH * 2 + metaH * (showFooter ? 2 : 1) + 12;
                    final showWeeks =
                        week != null &&
                        bounds.maxHeight >= titleH + metaH * 2 + 14;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Padding(
                                  padding: EdgeInsets.only(right: controlInset),
                                  child: AppTruncatedText(
                                    c.title.trim().isEmpty ? '未命名课程' : c.title,
                                    style: titleStyle,
                                  ),
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
                        if (showWeeks) ...[
                          const SizedBox(height: 4),
                          AppTruncatedText(week, style: metaStyle),
                        ],
                        if (showFooter) ...[
                          SizedBox(height: footerGap),
                          Text(
                            footer,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimetableDayHeading extends StatelessWidget {
  const _TimetableDayHeading({
    required this.day,
    required this.date,
    required this.isToday,
    required this.inline,
  });
  final int day;
  final DateTime? date;
  final bool isToday, inline;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: inline ? 4 : 2),
      padding: EdgeInsets.symmetric(
        horizontal: inline ? 8 : 4,
        vertical: inline ? 4 : 2,
      ),
      decoration: isToday
          ? BoxDecoration(
              color: p.accentSoft,
              border: Border.all(color: p.accentRim),
              borderRadius: BorderRadius.circular(AppRadii.card),
            )
          : null,
      child: Flex(
        direction: inline ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            weekdayLabel(day),
            maxLines: 1,
            softWrap: false,
            style: AppTypography.control.copyWith(
              fontSize: AppDensity.isTouch(context) ? 12 : 13,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
              color: isToday ? p.primary : p.ink,
            ),
          ),
          if (date != null) ...[
            SizedBox(width: inline ? 8 : 0, height: inline ? 0 : 2),
            Text(
              '${date!.month}/${date!.day}',
              key: ValueKey('timetable-date-$day'),
              maxLines: 1,
              softWrap: false,
              style: AppTypography.caption.copyWith(
                color: isToday ? p.primary : p.muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
