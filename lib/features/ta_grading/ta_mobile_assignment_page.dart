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

/// The mobile route only reads student submissions and score history.
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
      final result = await _repository.refreshStudents(
        widget.courseId,
        widget.assignment.id,
        graded: _summary.graded,
        onProgress: (students) {
          if (mounted && _repository.active) {
            setState(() {
              _students = students;
              _ready = true;
            });
          }
        },
      );
      if (mounted && _repository.active) {
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
      child: PageScaffold(
        title: '作业进度',
        onBack: () => Navigator.of(context).maybePop(),
        child: FutureBuilder<List<TaStudent>>(
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
                    .where((s) => '${s.name} ${s.number}'.contains(_query))
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
                        TaOverview(
                          title: widget.assignment.title,
                          total: _summary.expected,
                          submitted: _summary.submitted,
                          graded: _summary.graded,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(AppIcons.desktop, size: 16, color: p.muted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '打包下载与批量评分请使用电脑端',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(color: p.muted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '学生提交',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        AppSearchField(
                          hintText: '搜索姓名或学号',
                          onChanged: (value) => setState(() => _query = value),
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  }
                  if (index == students.length + 1) {
                    return students.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('没有匹配的学生')),
                          )
                        : const SizedBox(height: 12);
                  }
                  final s = students[index - 1];
                  return ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: index == 1
                          ? const Radius.circular(AppRadii.card)
                          : Radius.zero,
                      bottom: index == students.length
                          ? const Radius.circular(AppRadii.card)
                          : Radius.zero,
                    ),
                    child: TaStudentRow(
                      student: s,
                      gradingKnown: _summary.graded == 0,
                    ),
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
