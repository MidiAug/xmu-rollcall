import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:flutter/material.dart';
import 'homework_list_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/app/refresh_feedback.dart';
import 'package:xmu_rollcall/core/network/request_failure.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
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
    required this.detailBuilder,
    this.courseName = '',
    this.initialFilter = HomeworkCourseFilter.all,
  });

  final int courseId;
  final Widget Function(HomeworkItem) detailBuilder;
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
    AppPageRoutes.push(context, widget.detailBuilder(seeded));
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

    final catalogProvider = ref.watch(
      scopedCourseCatalogProvider(ref.watch(selectedRollcallAccountProvider)),
    );
    final catalog = ref.exists(catalogProvider)
        ? ref.watch(catalogProvider).valueOrNull
        : null;
    var teachers = '';
    for (final course in catalog?.courses ?? []) {
      if (course.id == '${widget.courseId}') {
        teachers = course.instructorsLabel;
        break;
      }
    }
    final touch = AppDensity.isTouch(context);
    final refreshExtent = AppDensity.isTouch(context)
        ? AppMobileUi.target
        : 34.0;
    return SubpageScaffold(
      title: title,
      actions: [
        if (!touch && teachers.isNotEmpty)
          Text(
            '课程教师  $teachers',
            style: AppTypography.body.copyWith(color: p.muted),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: refreshExtent,
              height: refreshExtent,
              child: AppRefreshButton(
                onRefresh: () => ref
                    .read(courseHomeworkProvider(widget.courseId).notifier)
                    .refresh(),
              ),
            ),
          ],
        ),
      ],
      body: AppPageViewport(
        maxWidth: AppLayout.workspaceMaxWidth,
        builder: (context, toolbarInsets) => Column(
          children: [
            Padding(
              padding: toolbarInsets + EdgeInsets.fromLTRB(pageX, 8, pageX, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppSegmentedControl<HomeworkCourseFilter>(
                  key: const ValueKey('homework-course-filter'),
                  value: _filter,
                  trackOnTouch: true,
                  expanded: AppDensity.isTouch(context),
                  onChanged: (v) => setState(() => _filter = v),
                  segments: [
                    for (final filter in HomeworkCourseFilter.values)
                      AppSegment(
                        value: filter,
                        label:
                            '${filter == HomeworkCourseFilter.all ? '全部' : filter.label} ${async.valueOrNull?.where(filter.matches).length ?? 0}',
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AppPageViewport(
                maxWidth: AppLayout.workspaceMaxWidth,
                builder: (context, contentInsets) => RefreshFeedback(
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
                      skipLoadingOnReload: async.hasValue,
                      skipLoadingOnRefresh: async.hasValue,
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: contentInsets + EdgeInsets.all(pageX),
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
                                  icon: AppIcons.homework,
                                  title: items.isEmpty
                                      ? '本课暂无作业'
                                      : '当前没有${_filter.label}的作业',
                                ),
                              ),
                            ],
                          );
                        }
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding:
                              contentInsets +
                              EdgeInsets.fromLTRB(
                                pageX,
                                AppSpace.md,
                                pageX,
                                AppSpace.xl,
                              ),
                          children: [
                            if (touch && teachers.isNotEmpty)
                              SettingsSection(
                                header: '教学信息',
                                hasLeading: false,
                                padTop: false,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(AppSpace.md),
                                    child: Text('课程教师  $teachers'),
                                  ),
                                ],
                              ),
                            for (final closed in [false, true])
                              if (filtered.any(
                                (item) => item.isOverdue == closed,
                              ))
                                SettingsSection(
                                  headerStyle: AppTypography.body.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: p.ink,
                                  ),
                                  header:
                                      '${closed ? '已截止' : '进行中'}  ${filtered.where((item) => item.isOverdue == closed).length}',
                                  hasLeading: false,
                                  padTop: closed,
                                  children: [
                                    for (final item in filtered.where(
                                      (item) => item.isOverdue == closed,
                                    ))
                                      HomeworkListRow(
                                        item: item,
                                        subtitle: widget.courseName,
                                        compactTrailing: HomeworkStatusBadges(
                                          item: item,
                                          compact: true,
                                        ),
                                        trailing: HomeworkStatusBadges(
                                          item: item,
                                          withDeadline: true,
                                          compact: true,
                                        ),
                                        onTap: () => _openDetail(item),
                                      ),
                                  ],
                                ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
