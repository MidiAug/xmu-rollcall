import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';

/// 某课全部作业（只读，按需拉取）。
class HomeworkCoursePage extends ConsumerStatefulWidget {
  const HomeworkCoursePage({
    super.key,
    required this.courseId,
    this.courseName = '',
  });

  final int courseId;
  final String courseName;

  @override
  ConsumerState<HomeworkCoursePage> createState() => _HomeworkCoursePageState();
}

class _HomeworkCoursePageState extends ConsumerState<HomeworkCoursePage> {
  var _appeared = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _appeared) return;
      _appeared = true;
      ref
          .read(courseHomeworkProvider(widget.courseId).notifier)
          .ensureFresh();
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
    final p = AppPalette.of(context);
    final pageX = AppSpace.pageXOf(context);
    final title =
        widget.courseName.isEmpty ? '课程作业' : widget.courseName;
    final async = ref.watch(courseHomeworkProvider(widget.courseId));

    return SubpageScaffold(
      title: title,
      actions: [
        AppRefreshButton(
          onRefresh: () => ref
              .read(courseHomeworkProvider(widget.courseId).notifier)
              .refresh(),
        ),
      ],
      body: AppContentColumn(
        child: AppPullToRefresh(
          color: p.primary,
          onRefresh: () => ref
              .read(courseHomeworkProvider(widget.courseId).notifier)
              .refresh(),
          child: async.when(
            skipLoadingOnReload: true,
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
                      Text('$e', style: TextStyle(color: p.muted)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref
                            .read(
                              courseHomeworkProvider(widget.courseId).notifier,
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
              if (items.isEmpty) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: const [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyHint(
                        icon: Icons.assignment_outlined,
                        title: '本课暂无作业',
                        detail: '下拉刷新',
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
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
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
                                    color:
                                        item.isOverdue ? p.danger : p.muted,
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
    );
  }
}
