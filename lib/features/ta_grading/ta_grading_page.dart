import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_service_symbol.dart';
import 'package:xmu_rollcall/app/app_sliver_group.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'ta_assignment_page.dart';
import 'ta_mobile_assignment_page.dart';
import 'ta_models.dart';
import 'ta_providers.dart';
import 'ta_repository.dart';
import 'ta_widgets.dart';

export 'ta_assignment_page.dart';

class TaGradingPage extends ConsumerWidget {
  const TaGradingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(taRepositoryProvider);
    final courses = ref.watch(currentTeachingCoursesProvider);
    return PageScaffold(
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).maybePop()
          : null,
      title: taIsMobile(context) ? '助教作业' : '修改作业',
      child: repository.when(
        skipLoadingOnReload: repository.hasValue,
        skipLoadingOnRefresh: repository.hasValue,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => TaFailureView(
          error: e,
          retry: () => ref.invalidate(taRepositoryProvider),
        ),
        data: (repo) => courses.when(
          skipLoadingOnReload: courses.hasValue,
          skipLoadingOnRefresh: courses.hasValue,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => TaFailureView(
            error: e,
            retry: () => ref.invalidate(currentTeachingCoursesProvider),
          ),
          data: (items) => _TaCourses(
            key: ObjectKey(repo),
            repository: repo,
            courses: items,
          ),
        ),
      ),
    );
  }
}

class _TaCourses extends StatefulWidget {
  const _TaCourses({
    super.key,
    required this.repository,
    required this.courses,
  });
  final TaGradingRepository repository;
  final List<CatalogCourse> courses;
  @override
  State<_TaCourses> createState() => _TaCoursesState();
}

class _TaCoursesState extends State<_TaCourses> {
  int? _course;
  int? _renderedCourse;
  List<TaAssignment>? _renderedAssignments;
  Future<List<TaAssignment>>? _assignments;
  Future<List<TaAssignment>> _readAssignments(
    int id, {
    bool refresh = false,
  }) async {
    await widget.repository.restoreAssignments(id);
    if (!mounted || _course != id) {
      return widget.repository.cachedAssignments(id)?.items ?? const [];
    }
    if (widget.repository.cachedAssignments(id) case final cached?) {
      setState(() {
        _renderedCourse = id;
        _renderedAssignments = cached.items;
      });
    }
    final items = await widget.repository.assignments(id, refresh: refresh);
    if (mounted && _course == id) {
      _renderedCourse = id;
      _renderedAssignments = items;
    }
    return items;
  }

  void _select(int id, {bool refresh = false}) {
    setState(() {
      _course = id;
      _assignments = _readAssignments(id, refresh: refresh);
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.courses.isNotEmpty) {
      _course = int.tryParse(widget.courses.first.id);
      if (_course != null) {
        _assignments = _readAssignments(_course!);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _TaCourses oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.courses.any((c) => c.id == '$_course')) {
      _course = widget.courses.isEmpty
          ? null
          : int.tryParse(widget.courses.first.id);
      _assignments = _course == null ? null : _readAssignments(_course!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    if (widget.courses.isEmpty) {
      return const EmptyHint(
        icon: AppIcons.people,
        title: '还没有助教课程',
        detail: '获得课程的教师或助教权限后，作业会显示在这里。',
      );
    }
    final course = widget.courses.firstWhere(
      (c) => c.id == '$_course',
      orElse: () => widget.courses.first,
    );
    return AppPageViewport(
      maxWidth: AppLayout.workspaceMaxWidth,
      builder: (context, contentInsets) => FutureBuilder<List<TaAssignment>>(
        key: ValueKey(_course),
        future: _assignments,
        initialData: _course == null
            ? null
            : widget.repository.cachedAssignments(_course!)?.items,
        builder: (context, snapshot) {
          final assignments =
              snapshot.data ??
              (_course == null
                  ? null
                  : widget.repository.cachedAssignments(_course!)?.items) ??
              (_renderedCourse == _course ? _renderedAssignments : null);
          if (snapshot.hasError && assignments == null) {
            return TaFailureView(
              error: snapshot.error!,
              retry: () => _select(_course!),
            );
          }
          if (assignments == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final pad =
              contentInsets +
              EdgeInsets.fromLTRB(
                AppSpace.pageXOf(context),
                8,
                AppSpace.pageXOf(context),
                24,
              );
          final cached = _course == null
              ? null
              : widget.repository.cachedAssignments(_course!);
          final checkedLabel = cached == null
              ? null
              : '上次核对 ${cached.checkedAt.toLocal().toString().substring(0, 16)}';
          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, bounds) {
                  final wideHeader = bounds.maxWidth >= 520;
                  final checkedText = checkedLabel == null
                      ? null
                      : Text(
                          checkedLabel,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: p.muted),
                        );
                  return Row(
                    children: [
                      const AppServiceSymbol(
                        size: 44,
                        icon: AppIcons.serviceGrading,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '助教课程',
                              style: TextStyle(color: p.muted, fontSize: 12),
                            ),
                            const SizedBox(height: 5),
                            AppTruncatedText(
                              course.title,
                              style: TextStyle(
                                color: p.ink,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!wideHeader && checkedText != null) ...[
                              const SizedBox(height: 4),
                              checkedText,
                            ],
                          ],
                        ),
                      ),
                      if (wideHeader && checkedText != null) ...[
                        const SizedBox(width: 12),
                        checkedText,
                      ],
                      const SizedBox(width: 12),
                      AppRefreshButton(
                        tooltip: '更新作业',
                        iconSize: 20,
                        busy:
                            snapshot.connectionState == ConnectionState.waiting,
                        onRefresh: () async {
                          if (_course != null) {
                            _select(_course!, refresh: true);
                            try {
                              await _assignments;
                            } catch (_) {
                              // FutureBuilder keeps cached content and reports the failure.
                            }
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
              if (widget.courses.length > 1) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in widget.courses)
                      SizedBox(
                        width: 220,
                        child: AppHoverSurface(
                          backgroundColor: c.id == '$_course'
                              ? p.selected
                              : p.surface,
                          hoverColor: c.id == '$_course'
                              ? p.selected
                              : p.cardHover,
                          pressedColor: c.id == '$_course'
                              ? p.selected
                              : p.controlPressed,
                          borderColor: p.borderStrong,
                          borderRadius: BorderRadius.circular(
                            AppRadii.control,
                          ),
                          padding: const EdgeInsets.all(12),
                          onTap: () {
                            final id = int.tryParse(c.id);
                            if (id != null && id != _course) {
                              _select(id);
                            }
                          },
                          child: Row(
                            children: [
                              Icon(
                                c.id == '$_course'
                                    ? AppIcons.checkCircle
                                    : AppIcons.person,
                                size: 16,
                                color: c.id == '$_course'
                                    ? p.primary
                                    : p.muted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: AppTruncatedText(c.title)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '更新失败，保留上次作业列表',
                    style: TextStyle(color: p.warning),
                  ),
                ),
              if (assignments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('这门课还没有作业'),
                ),
            ],
          );
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  pad.left,
                  pad.top,
                  pad.right,
                  assignments.isEmpty ? pad.bottom : 20,
                ),
                sliver: SliverToBoxAdapter(child: header),
              ),
              if (assignments.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    pad.left,
                    0,
                    pad.right,
                    pad.bottom,
                  ),
                  sliver: AppSliverGroup(
                    sliver: SliverList.separated(
                      itemCount: assignments.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                        color: p.divider,
                      ),
                      itemBuilder: (context, index) {
                        final item = assignments[index];
                        final pending = (item.submitted - item.graded).clamp(
                          0,
                          item.submitted,
                        );
                        return AppHoverSurface(
                          outlined: false,
                          quiet: true,
                          backgroundColor: Colors.transparent,
                          borderRadius: BorderRadius.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          onTap: () async {
                            final courseId = _course!;
                            await AppPageRoutes.push(
                              context,
                              taIsMobile(context)
                                  ? TaMobileAssignmentPage(
                                      repository: widget.repository,
                                      courseId: courseId,
                                      assignment: item,
                                    )
                                  : TaAssignmentPage(
                                      repository: widget.repository,
                                      courseId: courseId,
                                      assignment: item,
                                    ),
                            );
                            if (mounted &&
                                widget.repository.active &&
                                _course == courseId) {
                              _select(courseId);
                            }
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppTruncatedText(
                                      item.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: p.ink,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    TaAssignmentSummaryBar(assignment: item),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              AppStatusBadge(
                                item.submitted == 0
                                    ? '待提交'
                                    : item.graded > 0
                                    ? '已批 ${item.graded}/${item.submitted}'
                                    : '待批 $pending',
                                tone: item.submitted == 0
                                    ? AppStatusTone.neutral
                                    : item.graded > 0
                                    ? AppStatusTone.success
                                    : AppStatusTone.accent,
                                pill: true,
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                AppIcons.right,
                                size: 18,
                                color: p.muted,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
