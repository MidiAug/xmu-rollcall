import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';

class AcademicMappingPage extends ConsumerStatefulWidget {
  const AcademicMappingPage({
    super.key,
    required this.userId,
    required this.courses,
  });
  final int userId;
  final List<CatalogCourse> courses;
  @override
  ConsumerState<AcademicMappingPage> createState() =>
      _AcademicMappingPageState();
}

class _AcademicMappingPageState extends ConsumerState<AcademicMappingPage> {
  AcademicSchedule? _schedule;
  Map<String, String> _bindings = {};
  String? _error;
  bool _busy = true;
  bool _dirty = false;
  final Set<String> _editing = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final schedule = await AcademicScheduleStore.read(widget.userId);
    final bindings = schedule == null
        ? <String, String>{}
        : await AcademicBindings.read(widget.userId, schedule.term);
    if (mounted) {
      setState(() {
        _schedule = schedule;
        _bindings = {
          for (final e in bindings.entries)
            if (widget.courses.any((c) => c.id == e.key && !c.isTeaching) &&
                schedule!.groups.containsKey(e.value))
              e.key: e.value,
        };
        _busy = false;
      });
    }
  }

  Future<void> _save() async {
    final schedule = _schedule;
    if (schedule == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (ref.read(authControllerProvider).profile?.id != widget.userId ||
          (await AcademicScheduleStore.read(widget.userId))?.term !=
              schedule.term) {
        throw StateError('账号或学期已变化，请重新打开');
      }
      await AcademicBindings.write(widget.userId, schedule.term, _bindings);
      ref.read(academicRevisionProvider.notifier).state++;
      if (mounted) {
        setState(() => _dirty = false);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) setState(() => _error = '未保存，请检查课程是否重复关联');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _schedule?.groups ?? {};
    final courses = widget.courses.where((c) => !c.isTeaching).toList();
    final pending = courses
        .where(
          (c) =>
              !c.academicMatched ||
              _bindings.containsKey(c.id) ||
              _editing.contains(c.id),
        )
        .toList();
    final matched = courses.where((c) => !pending.contains(c)).toList();
    return SubpageScaffold(
      title: '关联课程',
      hasUnsavedChanges: () => _dirty,
      isBusy: () => _busy,
      actions: [
        TextButton(
          onPressed: _busy || _schedule == null || !_dirty ? null : _save,
          child: const Text('保存'),
        ),
      ],
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _schedule == null
          ? const Center(child: Text('请先同步教务课表'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(pending.isEmpty ? '课程已自动关联' : '请选择对应的教务课程'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                for (final c in pending)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTruncatedText(c.title),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) => AppShellSelect<String>(
                            key: ValueKey('academic-binding-${c.id}'),
                            semanticLabel: '关联教务课程',
                            width: constraints.maxWidth,
                            value: groups.containsKey(_bindings[c.id])
                                ? _bindings[c.id]!
                                : '',
                            items: ['', ...groups.keys],
                            wrapMenuLabels: true,
                            labelOf: (key) => key.isEmpty
                                ? '自动关联'
                                : '${groups[key]!.first.courseName} · ${groups[key]!.first.teachingClassName} · ${groups[key]!.first.instructor}',
                            onChanged: (value) => setState(() {
                              _dirty = true;
                              if (value.isEmpty) {
                                _bindings.remove(c.id);
                              } else {
                                _bindings[c.id] = value;
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (matched.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ExpansionTile(
                      title: Text('已关联（${matched.length}）'),
                      children: [
                        for (final c in matched)
                          ListTile(
                            title: Text(c.title),
                            trailing: TextButton(
                              onPressed: () =>
                                  setState(() => _editing.add(c.id)),
                              child: const Text('修改'),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
