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
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = '未保存，请检查是否重复对应，或账号、学期已变化');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _schedule?.groups ?? {};
    return SubpageScaffold(
      title: '课程对应',
      actions: [
        TextButton(
          onPressed: _busy || _schedule == null ? null : _save,
          child: const Text('保存'),
        ),
      ],
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _schedule == null
          ? const Center(child: Text('尚未获取教务课表，请先同步课表'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '能唯一识别的课程会自动对应。同名多班或名称不同的课程，可在这里指定教务教学班；选择自动对应可移除手动指定。',
                ),
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
                for (final c in widget.courses.where((c) => !c.isTeaching))
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('academic-binding-${c.id}'),
                      isExpanded: true,
                      initialValue: groups.containsKey(_bindings[c.id])
                          ? _bindings[c.id]
                          : '',
                      decoration: InputDecoration(labelText: c.title),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('自动对应')),
                        for (final e in groups.entries)
                          DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              '${e.value.first['KCMC']} · ${e.value.first['BJMC'] ?? ''} · ${e.value.first['JSXM'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        if (value == null || value.isEmpty) {
                          _bindings.remove(c.id);
                        } else {
                          _bindings[c.id] = value;
                        }
                      }),
                    ),
                  ),
              ],
            ),
    );
  }
}
