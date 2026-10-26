import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/shell_tab_exit_guard.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/location/course_meeting.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_picker.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/course_period_clock.dart';
import 'package:xmu_rollcall/features/settings/schedule_status_chip.dart';

class CourseSchedulesPage extends ConsumerWidget {
  const CourseSchedulesPage({super.key, this.assistUserId});
  final int? assistUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(scopedCourseCatalogProvider(assistUserId));
    final all = ref.watch(catalog).valueOrNull?.courses ?? <CatalogCourse>[];
    final courses = all.where((c) => !c.hasPlatformSchedule).toList();
    final p = AppPalette.of(context);
    return SubpageScaffold(
      title: '补全上课安排',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('完善你的课表', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                '为未排课的课程选择上课节次和地点。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              for (final course in courses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SettingsSection(
                    children: [
                      SettingsRow(
                        leading: const Icon(Icons.event_note_outlined),
                        title: course.title,
                        subtitle: course.needsSchedule
                            ? '尚未设置上课安排'
                            : course.localMeetings
                                  .map(
                                    (m) =>
                                        '${weekdayLabel(m.weekday)} 第${m.first}–${m.last}节',
                                  )
                                  .join(' · '),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (course.needsSchedule) ...[
                              const ScheduleStatusChip(),
                              const SizedBox(width: 8),
                            ],
                            Icon(
                              Icons.chevron_right_rounded,
                              color: p.muted,
                              size: 18,
                            ),
                          ],
                        ),
                        onTap: () {
                          final owner = ref
                              .read(authControllerProvider)
                              .profile
                              ?.id;
                          if (owner == null) return;
                          final uid = assistUserId ?? owner;
                          showDialog<void>(
                            context: context,
                            useRootNavigator: false,
                            barrierDismissible: false,
                            builder: (_) => CourseScheduleEditor(
                              course: course,
                              assistUserId: assistUserId,
                              onSave: (meetings) => ref
                                  .read(catalog.notifier)
                                  .saveMeetings(
                                    uid,
                                    course.id,
                                    meetings,
                                    expectedOwnerId: owner,
                                  ),
                              onSaveLocations: (locations) async {
                                if (ref
                                        .read(authControllerProvider)
                                        .profile
                                        ?.id !=
                                    owner) {
                                  throw StateError('账号已切换');
                                }
                                final controller = ref.read(
                                  courseRadarDefaultsForProvider(
                                    assistUserId,
                                  ).notifier,
                                );
                                for (final entry in locations.entries) {
                                  if (ref
                                              .read(authControllerProvider)
                                              .profile
                                              ?.id !=
                                          owner ||
                                      (assistUserId != null &&
                                          !ref
                                              .read(assistControllerProvider)
                                              .identities
                                              .any(
                                                (i) => i.userId == assistUserId,
                                              ))) {
                                    throw StateError('账号已切换或协助身份已移除');
                                  }
                                  final place = entry.value;
                                  await controller.configureForCourse(
                                    courseId: course.id,
                                    courseTitle: course.title,
                                    meetingKeys: [entry.key],
                                    selection: RadarGeoSelection(
                                      latitude: place.latitude,
                                      longitude: place.longitude,
                                      accuracy: place.accuracy,
                                      obtainedVia: RadarObtainedVia.place,
                                      placeId: place.id,
                                      label: place.note,
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              if (courses.isEmpty)
                const EmptyHint(
                  icon: Icons.event_available_outlined,
                  title: '课程安排已完整',
                  detail: '所有课程都已有上课安排',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CourseScheduleEditor extends ConsumerStatefulWidget {
  const CourseScheduleEditor({
    super.key,
    required this.course,
    required this.onSave,
    this.onSaveLocations,
    this.assistUserId,
  });
  final CatalogCourse course;
  final Future<void> Function(List<CourseMeeting>) onSave;
  final Future<void> Function(Map<String, SavedLocation>)? onSaveLocations;
  final int? assistUserId;
  @override
  ConsumerState<CourseScheduleEditor> createState() =>
      _CourseScheduleEditorState();
}

class _MeetingDraft {
  _MeetingDraft([this.original])
    : weekday = original?.weekday ?? 1,
      first = original?.first ?? 1,
      count = original == null ? 2 : original.last - original.first + 1;
  final CourseMeeting? original;
  int weekday, first, count;
  bool periodsChanged = false;
  SavedLocation? selected;
  int get last => first + count - 1;
  CourseMeeting meeting(Map<int, PeriodTime> clock) => CourseMeeting(
    weekday: weekday,
    first: first,
    last: last,
    startMinutes: !periodsChanged && original != null
        ? original!.startMinutes
        : clock[first]!.start,
    endMinutes: !periodsChanged && original != null
        ? original!.endMinutes
        : clock[last]!.end,
    classroom: selected?.note ?? original?.classroom ?? '',
  );
  String key(Map<int, PeriodTime> clock) {
    final m = meeting(clock);
    return courseMeetingKey(m.weekday, courseMeetingBlocks([m.slot]).single);
  }

  String? get originalKey => original == null
      ? null
      : courseMeetingKey(
          original!.weekday,
          courseMeetingBlocks([original!.slot]).single,
        );
}

class _CourseScheduleEditorState extends ConsumerState<CourseScheduleEditor> {
  late final _clock = _buildClock();
  Map<int, PeriodTime> _buildClock() {
    final clock = coursePeriodClock();
    for (final m in widget.course.localMeetings) {
      clock.putIfAbsent(
        m.first,
        () => (start: m.startMinutes, end: m.startMinutes + 45),
      );
      clock.putIfAbsent(
        m.last,
        () => (start: m.endMinutes - 45, end: m.endMinutes),
      );
    }
    return clock;
  }

  late final List<_MeetingDraft> _drafts = widget.course.localMeetings.isEmpty
      ? [_MeetingDraft()]
      : widget.course.localMeetings.map(_MeetingDraft.new).toList();
  bool _dirty = false, _saving = false;
  String? _error;
  _MeetingDraft? _picking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref
            .read(courseRadarDefaultsForProvider(widget.assistUserId).notifier)
            .reload();
      } catch (_) {
        /* Preserve the visible draft if local memory cannot load. */
      }
    });
  }

  CourseRadarPref? _preference(_MeetingDraft d) => ref
      .read(courseRadarDefaultsForProvider(widget.assistUserId).notifier)
      .forCourse(
        courseId: widget.course.id,
        meetingKey: d.originalKey ?? d.key(_clock),
      );
  SavedLocation? _savedPlace(_MeetingDraft d) {
    if (d.selected != null) return d.selected;
    final pref = _preference(d);
    final id = pref?.placeId;
    for (final place in ref.read(savedLocationsProvider)) {
      if (place.id == id) return place;
    }
    if (pref == null) {
      for (final draft in _drafts) {
        if (draft.selected != null) return draft.selected;
      }
    }
    return null;
  }

  Future<void> _close() async {
    if (_saving) return;
    if (_picking != null) {
      setState(() => _picking = null);
      return;
    }
    if (_dirty &&
        !await showAppConfirmDialog(
          context,
          title: '放弃修改？',
          message: '上课安排尚未保存。',
          confirmLabel: '放弃修改',
        )) {
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (_saving) return;
    final meetings = _drafts.map((d) {
      final m = d.meeting(_clock);
      return CourseMeeting(
        weekday: m.weekday,
        first: m.first,
        last: m.last,
        startMinutes: m.startMinutes,
        endMinutes: m.endMinutes,
        classroom: _savedPlace(d)?.note ?? m.classroom,
      );
    }).toList();
    // Validate before either schedule or location changes are persisted.
    for (var i = 0; i < meetings.length; i++) {
      for (final b in meetings.skip(i + 1)) {
        final a = meetings[i];
        if (a.weekday == b.weekday &&
            ((a.first <= b.last && b.first <= a.last) ||
                (a.startMinutes < b.endMinutes &&
                    b.startMinutes < a.endMinutes))) {
          setState(() => _error = '同一天的上课安排不能重叠');
          return;
        }
      }
    }
    final locations = <String, SavedLocation>{
      for (final d in _drafts)
        if (d.selected != null ||
            (d.originalKey != null &&
                d.originalKey != d.key(_clock) &&
                _savedPlace(d) != null))
          d.key(_clock): _savedPlace(d)!,
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(meetings);
      await widget.onSaveLocations?.call(locations);
      if (mounted) {
        setState(() => _dirty = false);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException ? e.message : '保存失败，请确认账号后重试',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<int> _counts(int first) {
    var length = 0;
    while (_clock.containsKey(first + length)) {
      length++;
    }
    return List.generate(length, (i) => i + 1);
  }

  Widget _field(String title, Widget child, double width) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );

  Widget _card(_MeetingDraft d) {
    final p = AppPalette.of(context);
    final m = d.meeting(_clock);
    final place = _savedPlace(d);
    final pref = _preference(d);
    final label =
        place?.note ??
        (pref?.labelSnapshot.isNotEmpty == true
            ? pref!.labelSnapshot
            : d.original?.classroom.isNotEmpty == true
            ? d.original!.classroom
            : '选择或添加地点');
    return Container(
      key: ObjectKey(d),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '第 ${_drafts.indexOf(d) + 1} 次上课',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '删除本次安排',
                visualDensity: VisualDensity.compact,
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        _drafts.remove(d);
                        _dirty = true;
                      }),
                icon: Icon(
                  Icons.remove_circle_outline_rounded,
                  size: 18,
                  color: p.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, size) {
              final narrow = size.maxWidth < 390;
              final third = (size.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 12,
                children: [
                  _field(
                    '星期',
                    AppShellSelect<int>(
                      value: d.weekday,
                      items: List.generate(7, (i) => i + 1),
                      labelOf: weekdayLabel,
                      width: narrow ? size.maxWidth : third,
                      semanticLabel: '星期',
                      onChanged: _saving
                          ? null
                          : (v) => setState(() {
                              d.weekday = v;
                              _dirty = true;
                            }),
                    ),
                    narrow ? size.maxWidth : third,
                  ),
                  _field(
                    '开始节次',
                    AppShellSelect<int>(
                      value: d.first,
                      items: ({..._clock.keys, d.first}.toList()..sort()),
                      labelOf: (v) => '第 $v 节',
                      width: narrow ? (size.maxWidth - 8) / 2 : third,
                      semanticLabel: '开始节次',
                      onChanged: _saving
                          ? null
                          : (v) => setState(() {
                              d.first = v;
                              d.count = d.count.clamp(1, _counts(v).length);
                              d.periodsChanged = true;
                              _dirty = true;
                            }),
                    ),
                    narrow ? (size.maxWidth - 8) / 2 : third,
                  ),
                  _field(
                    '连续上课',
                    AppShellSelect<int>(
                      value: d.count,
                      items: ({..._counts(d.first), d.count}.toList()..sort()),
                      labelOf: (v) => '上 $v 节',
                      width: narrow ? (size.maxWidth - 8) / 2 : third,
                      semanticLabel: '上课节数',
                      onChanged: _saving
                          ? null
                          : (v) => setState(() {
                              d.count = v;
                              d.periodsChanged = true;
                              _dirty = true;
                            }),
                    ),
                    narrow ? (size.maxWidth - 8) / 2 : third,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: p.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${periodTimeLabel(m.startMinutes)}–${periodTimeLabel(m.endMinutes)}  ·  第 ${m.first}–${m.last} 节',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('上课地点', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          AppHoverSurface(
            key: ValueKey('meeting-location-${_drafts.indexOf(d)}'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            onTap: _saving ? null : () => setState(() => _picking = d),
            child: Row(
              children: [
                Icon(Icons.place_outlined, size: 18, color: p.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(courseRadarDefaultsForProvider(widget.assistUserId));
    ref.watch(savedLocationsProvider);
    final p = AppPalette.of(context);
    final picking = _picking;
    return ShellTabExitGuard(
      hasUnsavedChanges: () => _dirty,
      isBusy: () => _saving,
      child: PopScope(
        canPop: !_dirty && !_saving && picking == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Dialog(
          backgroundColor: p.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(context).height * .85,
            ),
            child: picking != null
                ? LocationPickerContent(
                    title: '选择上课地点',
                    selectedId: _savedPlace(picking)?.id,
                    onSelected: (place) => setState(() {
                      picking.selected = place;
                      _dirty = true;
                      _picking = null;
                    }),
                    onBack: () => setState(() => _picking = null),
                    onClose: () => setState(() => _picking = null),
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.course.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '选择开始节次和节数，时间自动计算。每次上课可设置不同地点。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final d in _drafts) _card(d),
                                if (_drafts.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 24,
                                    ),
                                    child: Text(
                                      '还没有上课安排',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                TextButton.icon(
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() {
                                          _drafts.add(_MeetingDraft());
                                          _dirty = true;
                                        }),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('添加一次上课'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _error!,
                              style: TextStyle(color: p.danger),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _saving ? null : _close,
                              child: const Text('取消'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _saving ? null : _save,
                              child: Text(_saving ? '保存中…' : '保存'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
