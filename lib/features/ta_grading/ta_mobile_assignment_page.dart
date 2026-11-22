import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/network/request_failure.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'ta_models.dart';
import 'ta_providers.dart';
import 'ta_repository.dart';
import 'ta_widgets.dart';

/// The mobile route reads the roster and bulk final grades without writes.
class TaMobileAssignmentPage extends ConsumerStatefulWidget {
  const TaMobileAssignmentPage({
    super.key,
    required this.repository,
    required this.courseId,
    required this.assignment,
  });
  final TaGradingRepository repository;
  final int courseId;
  final TaAssignment assignment;
  @override
  ConsumerState<TaMobileAssignmentPage> createState() =>
      _TaMobileAssignmentPageState();
}

class _TaMobileAssignmentPageState extends ConsumerState<TaMobileAssignmentPage>
    with ShellTabAware<TaMobileAssignmentPage> {
  @override
  AppDestination get shellTab => AppDestination.campusTools;
  @override
  void onShellTabHidden() {
    super.onShellTabHidden();
    _repository.dispose();
  }

  late final TaGradingRepository _repository;
  late Future<List<TaStudent>> _loading;
  List<TaStudent> _students = [];
  late TaAssignment _summary;
  bool _ready = false;
  String _query = '';
  int _submission = 0;
  bool _showSearch = false;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository.fork();
    _summary = widget.assignment;
    _loading = _load();
  }

  Future<List<TaStudent>> _load() async {
    try {
      final cached = await _repository.restoreStudents(
        widget.courseId,
        widget.assignment.id,
      );
      if (!mounted || !_repository.active) return [];
      if (cached != null && !_ready) {
        setState(() {
          _students = cached.students;
          _ready = true;
        });
      }
      await _repository.detail(widget.courseId, widget.assignment.id);
      if (!mounted || !_repository.active) return [];
      final assignments = await _repository.assignments(widget.courseId);
      if (!mounted || !_repository.active) return [];
      setState(
        () => _summary = assignments.firstWhere(
          (a) => a.id == widget.assignment.id,
          orElse: () => _summary,
        ),
      );
      final result = await _repository.students(
        widget.courseId,
        widget.assignment.id,
      );
      if (mounted && _repository.active) {
        setState(() {
          _students = result;
          _ready = true;
        });
        await _repository.cacheStudents(
          widget.courseId,
          widget.assignment.id,
          result,
        );
      }
      return result;
    } catch (_) {
      if (!mounted || !_repository.active) return [];
      if (!_ready) rethrow;
      AppToast.show(context, '更新失败，保留已加载的名单和成绩', error: true);
      return _students;
    }
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (!identical(
      ref.watch(taRepositoryProvider).valueOrNull,
      widget.repository,
    )) {
      return const PageScaffold(
        title: '助教作业',
        child: Center(child: Text('账号已变更，请返回重新查看')),
      );
    }
    if (!_repository.active) {
      return const PageScaffold(
        title: '助教作业',
        child: Center(child: Text('请返回重新打开作业')),
      );
    }
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _repository.dispose();
      },
      child: SubpageScaffold(
        title: widget.assignment.title,
        actions: [
          AppIconButton(
            tooltip: '搜索学生',
            icon: const Icon(AppIcons.search),
            onPressed: () => setState(() => _showSearch = !_showSearch),
          ),
        ],
        onBack: () => Navigator.of(context).maybePop(),
        body: FutureBuilder<List<TaStudent>>(
          future: _loading,
          builder: (context, snapshot) {
            if (snapshot.hasError && !_ready) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(requestFailureMessage(snapshot.error)),
                    AppButton(
                      label: '重新加载',
                      kind: AppButtonKind.secondary,
                      onPressed: () => setState(() {
                        _loading = _load();
                      }),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData && !_ready) {
              return const Center(child: CircularProgressIndicator());
            }
            final students =
                {
                      for (final s in snapshot.data ?? <TaStudent>[]) s.id: s,
                      for (final s in _students) s.id: s,
                    }.values
                    .where(
                      (s) =>
                          '${s.name} ${s.number}'.contains(_query) &&
                          (_submission == 0 ||
                              (_submission == 1) == s.submitted),
                    )
                    .toList();
            return Material(
              color: Colors.transparent,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: students.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TaAssignmentSummaryBar(assignment: _summary),
                        ),
                        AppSegmentedControl<int>(
                          key: const ValueKey('ta-mobile-status'),
                          value: _submission,
                          expanded: true,
                          trackOnTouch: true,
                          segments: [
                            AppSegment(
                              value: 0,
                              label: '全部 ${_students.length}',
                            ),
                            AppSegment(
                              value: 1,
                              label:
                                  '已交 ${_students.where((s) => s.submitted).length}',
                            ),
                            AppSegment(
                              value: 2,
                              label:
                                  '未交 ${_students.where((s) => !s.submitted).length}',
                            ),
                          ],
                          onChanged: (v) => setState(() => _submission = v),
                        ),
                        if (_showSearch || _query.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          AppSearchField(
                            hintText: '搜索姓名或学号',
                            autofocus: _showSearch,
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                  if (index == students.length + 1) {
                    return students.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('没有匹配的学生')),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              '打包下载与批量评分请使用电脑端',
                              style: TextStyle(color: p.muted, fontSize: 12),
                            ),
                          );
                  }
                  final s = students[index - 1];
                  return TaStudentRow(
                    student: s,
                    gradingKnown: _summary.graded == 0,
                    showAvatar: _query.isNotEmpty,
                    isFirst: index == 1,
                    isLast: index == students.length,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
