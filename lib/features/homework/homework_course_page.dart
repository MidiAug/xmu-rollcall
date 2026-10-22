import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/app/refresh_feedback.dart';
import 'package:xmu_rollcall/core/network/request_failure.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_status_badges.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

enum HomeworkCourseFilter { all, ongoing, closed }

extension on HomeworkCourseFilter {
  String get label => switch (this) {
    HomeworkCourseFilter.all => '全部作业',
    HomeworkCourseFilter.ongoing => '进行中',
    HomeworkCourseFilter.closed => '已截止',
  };
  bool matches(HomeworkItem item) => switch (this) {
    HomeworkCourseFilter.all => true,
    HomeworkCourseFilter.ongoing => !item.isOverdue,
    HomeworkCourseFilter.closed => item.isOverdue,
  };
}

/// 某课全部作业（只读，按需拉取）。
class HomeworkCoursePage extends ConsumerStatefulWidget {
  const HomeworkCoursePage({
    super.key,
    required this.courseId,
    this.courseName = '',
    this.initialFilter = HomeworkCourseFilter.all,
  });

  final int courseId;
  final String courseName;
  final HomeworkCourseFilter initialFilter;

  @override
  ConsumerState<HomeworkCoursePage> createState() => _HomeworkCoursePageState();
}

class _HomeworkCoursePageState extends ConsumerState<HomeworkCoursePage> {
  var _appeared = false;
  late HomeworkCourseFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _appeared) return;
      _appeared = true;
      ref.read(courseHomeworkProvider(widget.courseId).notifier).ensureFresh();
    });
  }

  void _openDetail(HomeworkItem item) {
    final courseId = widget.courseId;
    final courseName = widget.courseName;
    final seeded = item.courseId == null
        ? item.copyWith(courseId: courseId, courseName: courseName)
        : (item.courseName.isEmpty && courseName.isNotEmpty
              ? item.copyWith(courseName: courseName)
              : item);
    AppPageRoutes.push(context, HomeworkDetailPage(seed: seeded));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedRollcallAccountProvider, (before, after) {
      if (before == after) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    });
    final p = AppPalette.of(context);
    final pageX = AppSpace.pageXOf(context);
    final title = widget.courseName.isEmpty ? '课程作业' : widget.courseName;
    final async = ref.watch(courseHomeworkProvider(widget.courseId));

    return SubpageScaffold(
      title: title,
      actions: [
        Center(
          child: AppShellSelect<HomeworkCourseFilter>(
            key: const ValueKey('homework-course-filter'),
            value: _filter,
            items: HomeworkCourseFilter.values,
            labelOf: (v) => v.label,
            menuTrailingOf: (v) => async.hasValue
                ? '(${async.requireValue.where(v.matches).length})'
                : '',
            onChanged: (v) => setState(() => _filter = v),
            width: 100,
            menuWidth: 180,
          ),
        ),
        AppRefreshButton(
          onRefresh: () => ref
              .read(courseHomeworkProvider(widget.courseId).notifier)
              .refresh(),
        ),
      ],
      body: AppContentColumn(
        child: RefreshFeedback(
          error: async.hasValue ? async.error : null,
          onRetry: () => ref
              .read(courseHomeworkProvider(widget.courseId).notifier)
              .refresh(),
          child: AppPullToRefresh(
            color: p.primary,
            onRefresh: () => ref
                .read(courseHomeworkProvider(widget.courseId).notifier)
                .refresh(),
            child: async.when(
              skipError: true,
              skipLoadingOnReload: false,
              skipLoadingOnRefresh: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(pageX),
                children: [
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '拉取失败',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          requestFailureMessage(e),
                          style: TextStyle(color: p.muted),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref
                              .read(
                                courseHomeworkProvider(
                                  widget.courseId,
                                ).notifier,
                              )
                              .refresh(),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              data: (items) {
                final filtered = items.where(_filter.matches).toList();
                if (filtered.isEmpty) {
                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyHint(
                          icon: Icons.assignment_outlined,
                          title: items.isEmpty
                              ? '本课暂无作业'
                              : '当前没有${_filter.label}的作业',
                          detail: '切换筛选或下拉刷新',
                        ),
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    pageX,
                    AppSpace.md,
                    pageX,
                    AppSpace.xl,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xs),
                      child: AppHoverSurface(
                        onTap: () => _openDetail(item),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title.isEmpty ? '未命名作业' : item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: p.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  HomeworkStatusBadges(item: item),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      item.dueLabel,
                                      if (item.status.isNotEmpty) item.status,
                                      if (item.type.isNotEmpty) item.type,
                                    ].join('  '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: p.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: p.muted),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
