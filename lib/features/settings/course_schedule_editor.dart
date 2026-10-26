import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/shell_tab_exit_guard.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

class CourseSchedulesPage extends ConsumerWidget {
  const CourseSchedulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses =
        ref
            .watch(courseCatalogProvider)
            .valueOrNull
            ?.courses
            .where((c) => !c.hasPlatformSchedule)
            .toList() ??
        <CatalogCourse>[];
    return SubpageScaffold(
      title: '补全上课安排',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('每次上课单独填写节次、时间和教室。未填写时，会参考历史上课日更新记录，并在每周结束后补查。'),
          ),
          for (final course in courses)
            ListTile(
              title: Text(course.title),
              subtitle: Text(
                course.needsSchedule
                    ? '待补全安排'
                    : '已补充 ${course.localMeetings.length} 次上课安排',
              ),
              trailing: course.needsSchedule
                  ? const Badge(child: Icon(Icons.edit_calendar_outlined))
                  : const Icon(Icons.edit_outlined),
              onTap: () {
                final uid = ref.read(authControllerProvider).profile?.id;
                if (uid == null) return;
                showDialog<void>(
                  context: context,
                  useRootNavigator: false,
                  barrierDismissible: false,
                  builder: (_) => CourseScheduleEditor(
                    course: course,
                    onSave: (meetings) => ref
                        .read(courseCatalogProvider.notifier)
                        .saveMeetings(uid, course.id, meetings),
                  ),
                );
              },
            ),
          if (courses.isEmpty) const Text('课程安排已完整'),
        ],
      ),
    );
  }
}

class CourseScheduleEditor extends StatefulWidget {
  const CourseScheduleEditor({
    super.key,
    required this.course,
    required this.onSave,
  });
  final CatalogCourse course;
  final Future<void> Function(List<CourseMeeting>) onSave;
  @override
  State<CourseScheduleEditor> createState() => _CourseScheduleEditorState();
}

class _MeetingDraft {
  _MeetingDraft([CourseMeeting? m])
    : weekday = m?.weekday ?? 1,
      first = m?.first ?? 1,
      last = m?.last ?? 3,
      start = TextEditingController(text: m == null ? '' : _hm(m.startMinutes)),
      end = TextEditingController(text: m == null ? '' : _hm(m.endMinutes)),
      room = TextEditingController(text: m?.classroom ?? '');
  int weekday;
  int first;
  int last;
  final TextEditingController start, end, room;
  static String _hm(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  void dispose() {
    start.dispose();
    end.dispose();
    room.dispose();
  }

  static int? minutes(String raw) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
    if (match == null) return null;
    final h = int.parse(match[1]!);
    final m = int.parse(match[2]!);
    return h <= 23 && m <= 59 ? h * 60 + m : null;
  }

  CourseMeeting? get meeting {
    final a = minutes(start.text);
    final b = minutes(end.text);
    if (a == null || b == null) return null;
    final value = CourseMeeting(
      weekday: weekday,
      first: first,
      last: last,
      startMinutes: a,
      endMinutes: b,
      classroom: room.text.trim(),
    );
    return value.valid ? value : null;
  }
}

class _CourseScheduleEditorState extends State<CourseScheduleEditor> {
  void _markDirty(String _) {
    if (!_dirty) setState(() => _dirty = true);
  }

  late final List<_MeetingDraft> _drafts = widget.course.localMeetings
      .map((m) => _MeetingDraft(m))
      .toList();
  bool _dirty = false;
  bool _saving = false;
  String? _error;
  Future<void> _close() async {
    if (_saving) return;
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
    final meetings = _drafts.map((d) => d.meeting).toList();
    if (meetings.contains(null)) {
      setState(() => _error = '请填写有效的起止节次和时间（如 14:30），结束须晚于开始');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(meetings.cast<CourseMeeting>());
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

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShellTabExitGuard(
    hasUnsavedChanges: () => _dirty,
    isBusy: () => _saving,
    child: PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.course.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('补充上课安排；每次上课可包含连续多节，教室分别保存。'),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final d in _drafts)
                          Padding(
                            key: ObjectKey(d),
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '第 ${_drafts.indexOf(d) + 1} 次上课',
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '删除本次安排',
                                      onPressed: _saving
                                          ? null
                                          : () {
                                              setState(() {
                                                _drafts.remove(d);
                                                _dirty = true;
                                              });
                                              // Dispose after the removed fields have unmounted.
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback(
                                                    (_) => d.dispose(),
                                                  );
                                            },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                LayoutBuilder(
                                  builder: (context, size) => Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      AppShellSelect<int>(
                                        value: d.weekday,
                                        items: List.generate(7, (i) => i + 1),
                                        labelOf: weekdayLabel,
                                        width: size.maxWidth < 420
                                            ? size.maxWidth
                                            : (size.maxWidth - 16) / 3,
                                        semanticLabel: '星期',
                                        onChanged: _saving
                                            ? null
                                            : (v) => setState(() {
                                                d.weekday = v;
                                                _dirty = true;
                                              }),
                                      ),
                                      AppShellSelect<int>(
                                        value: d.first,
                                        items: List.generate(20, (i) => i + 1),
                                        labelOf: (v) => '第$v节起',
                                        width: size.maxWidth < 420
                                            ? (size.maxWidth - 8) / 2
                                            : (size.maxWidth - 16) / 3,
                                        semanticLabel: '开始节次',
                                        onChanged: _saving
                                            ? null
                                            : (v) => setState(() {
                                                d.first = v;
                                                _dirty = true;
                                              }),
                                      ),
                                      AppShellSelect<int>(
                                        value: d.last,
                                        items: List.generate(20, (i) => i + 1),
                                        labelOf: (v) => '至第$v节',
                                        width: size.maxWidth < 420
                                            ? (size.maxWidth - 8) / 2
                                            : (size.maxWidth - 16) / 3,
                                        semanticLabel: '结束节次',
                                        onChanged: _saving
                                            ? null
                                            : (v) => setState(() {
                                                d.last = v;
                                                _dirty = true;
                                              }),
                                      ),
                                      for (final field in [
                                        (d.start, '开始时间'),
                                        (d.end, '结束时间'),
                                      ])
                                        SizedBox(
                                          width: (size.maxWidth - 8) / 2,
                                          child: TextField(
                                            controller: field.$1,
                                            enabled: !_saving,
                                            onChanged: _markDirty,
                                            decoration: InputDecoration(
                                              labelText: field.$2,
                                              hintText: '14:30',
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: d.room,
                                  enabled: !_saving,
                                  onChanged: _markDirty,
                                  decoration: const InputDecoration(
                                    labelText: '本次教室（选填）',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setState(() {
                                  _drafts.add(_MeetingDraft());
                                  _dirty = true;
                                }),
                          icon: const Icon(Icons.add),
                          label: const Text('添加一次上课'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: _saving ? null : _close,
                      child: const Text('取消'),
                    ),
                    const Spacer(),
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
