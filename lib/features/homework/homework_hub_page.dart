import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/desktop_shell_chrome.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/app/refresh_feedback.dart';
import 'package:xmu_rollcall/core/network/request_failure.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/homework/homework_overview.dart';
import 'package:xmu_rollcall/features/homework/homework_status_badges.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

Future<void> _refreshHomework(
  WidgetRef ref, {
  bool force = true,
  bool refreshStatuses = true,
}) async {
  final scope = ref.read(selectedRollcallAccountProvider);
  final owner = ref.read(authControllerProvider).profile?.id;
  final uid = scope ?? owner;
  if (force && uid != null) {
    ref.read(homeworkManualRefreshAtProvider(uid).notifier).state =
        DateTime.now();
  }
  await ref.read(homeworkOverviewProvider.notifier).ensureFresh(force: force);
  if (!ref.context.mounted) return;
  final lifecycle = WidgetsBinding.instance.lifecycleState;
  if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
  if (!(ShellTabScope.maybeOf(ref.context)?.isActive(AppDestination.homework) ??
      true)) {
    return;
  }
  if (!force && refreshStatuses) ref.invalidate(homeworkSubmissionProvider);
  List<CatalogCourse> courses;
  try {
    courses = await ref.read(currentTeachingCoursesProvider.future);
  } catch (_) {
    return;
  }
  for (final course in courses) {
    if (ref.read(selectedRollcallAccountProvider) != scope ||
        ref.read(authControllerProvider).profile?.id != owner) {
      return;
    }
    final id = int.tryParse(course.id);
    if (id != null) {
      await ref
          .read(courseHomeworkProvider(id).notifier)
          .ensureFresh(reason: EnsureFreshReason.appear);
    }
  }
}

/// 作业 Tab：只读待办列表。
class HomeworkHubPage extends ConsumerStatefulWidget {
  const HomeworkHubPage({super.key});

  @override
  ConsumerState<HomeworkHubPage> createState() => _HomeworkHubPageState();
}

class _HomeworkHubPageState extends ConsumerState<HomeworkHubPage>
    with ShellTabAware<HomeworkHubPage>, WidgetsBindingObserver {
  final _scroll = ScrollController();
  Timer? _timer;
  bool _foreground = true;
  bool _visible = false;
  DateTime? _lastCheckAt;
  (int?, int?)? _lastCheckIdentity;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (_visible && _foreground) {
      _timer = Timer.periodic(
        HomeworkOverviewNotifier.checkTtl,
        (_) => _checkFresh(refreshStatuses: true),
      );
    }
  }

  Future<void> _checkFresh({bool refreshStatuses = false}) async {
    if (!mounted ||
        !_visible ||
        !_foreground ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    if (ref.read(authControllerProvider).isSignedIn) {
      final identity = (
        ref.read(authControllerProvider).profile?.id,
        ref.read(selectedRollcallAccountProvider),
      );
      if (identity != _lastCheckIdentity) {
        _lastCheckIdentity = identity;
        _lastCheckAt = null;
      }
      if (_checking ||
          (_lastCheckAt != null &&
              ref.read(homeworkClockProvider)().difference(_lastCheckAt!) <
                  HomeworkOverviewNotifier.checkTtl)) {
        return;
      }
      _checking = true;
      _lastCheckAt = ref.read(homeworkClockProvider)();
      try {
        await _refreshHomework(
          ref,
          force: false,
          refreshStatuses: refreshStatuses,
        );
        if (mounted) setState(() {});
      } finally {
        _checking = false;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() => _foreground = state == AppLifecycleState.resumed);
    _syncTimer();
    if (_foreground) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkFresh());
    }
  }

  @override
  void onShellTabHidden() {
    _visible = false;
    _syncTimer();
    super.onShellTabHidden();
  }

  @override
  AppDestination get shellTab => AppDestination.homework;

  @override
  ScrollController? get shellScrollController => _scroll;

  @override
  void onShellTabVisible() {
    _visible = true;
    _syncTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  void _openDetail(HomeworkItem item) {
    AppPageRoutes.push(context, HomeworkDetailPage(seed: item));
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authControllerProvider).isSignedIn;
    final active =
        ShellTabScope.maybeOf(context)?.isActive(AppDestination.homework) ??
        true;

    final hostActions =
        PlatformHooks.isDesktop &&
        MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint &&
        DesktopShellChromeScope.maybeOf(context, listen: false) != null &&
        ShellTabDestination.maybeOf(context) != null;
    return DesktopRootActions(
      enabled: signedIn && hostActions,
      actions: const [_HomeworkRefreshAction()],
      child: PageScaffold(
        title: '作业',
        showHeader: false,
        child: AppContentColumn(
          child: PrimaryScrollController(
            controller: _scroll,
            child: !signedIn
                ? _SignedOutHint(onLogin: () => showLoginDialog(context))
                : active
                ? _TodosBody(onOpen: _openDetail, showToolbar: !hostActions)
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _SignedOutHint extends StatelessWidget {
  const _SignedOutHint({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return EmptyHint(
      icon: Icons.lock_outline,
      title: '尚未登录',
      detail: '登录后可查看待办作业',
      action: FilledButton.icon(
        onPressed: onLogin,
        icon: const Icon(Icons.login, size: 18),
        label: const Text('登录'),
      ),
    );
  }
}

class _TodosBody extends ConsumerWidget {
  const _TodosBody({required this.onOpen, required this.showToolbar});
  final bool showToolbar;

  final ValueChanged<HomeworkItem> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final pageX = AppSpace.pageXOf(context);
    final async = ref.watch(homeworkTodosProvider);
    final teaching = ref.watch(currentTeachingCoursesProvider);
    final overview = ref.watch(homeworkOverviewProvider);
    final visibleItems = overview.hasValue
        ? AsyncData(overview.requireValue.items)
        : async;
    final teachingCourses = teaching.valueOrNull ?? const <CatalogCourse>[];
    final teachingIds = teachingCourses.map((c) => c.id).toSet();

    final content = RefreshFeedback(
      error: async.hasValue ? async.error : null,
      onRetry: () => _refreshHomework(ref),
      child: AppPullToRefresh(
        color: p.primary,
        onRefresh: () => _refreshHomework(ref),
        child: visibleItems.when(
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
                      onPressed: () =>
                          ref.read(homeworkTodosProvider.notifier).refresh(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          data: (items) {
            if (teaching.isLoading && !teaching.hasValue) {
              return const Center(child: CircularProgressIndicator());
            }
            final studentItems = (overview.valueOrNull?.items ?? items)
                .where((i) => !teachingIds.contains('${i.courseId}'))
                .toList();
            if (studentItems.isEmpty && teachingCourses.isEmpty) {
              if (overview.isLoading ||
                  (overview.valueOrNull?.pendingRefresh ?? false)) {
                return const Center(child: CircularProgressIndicator());
              }
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: const [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyHint(
                      icon: Icons.assignment_turned_in_outlined,
                      title: '暂无作业',
                      detail: '下拉刷新即可',
                    ),
                  ),
                ],
              );
            }
            final upcoming = studentItems
                .where((e) => !e.isOverdue)
                .toList(growable: false);
            final overdue = studentItems
                .where((e) => e.isOverdue)
                .toList(growable: false);
            final rows = <Widget>[
              if ((overview.valueOrNull?.failedCourses ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '部分课程暂未更新，显示已有记录',
                    style: TextStyle(fontSize: 12, color: p.muted),
                  ),
                ),

              if (teachingCourses.isNotEmpty) ...[
                for (final course in teachingCourses)
                  _TeachingCourseCard(course: course, onOpen: onOpen),
                if (studentItems.isNotEmpty)
                  const SizedBox(height: AppSpace.md),
              ],
              if (upcoming.isNotEmpty) ...[
                _SectionLabel(label: '进行中  ${upcoming.length}'),
                const SizedBox(height: AppSpace.xs),
                for (final item in upcoming)
                  _TodoTile(item: item, onTap: () => onOpen(item)),
              ],
              if (overdue.isNotEmpty) ...[
                if (upcoming.isNotEmpty) const SizedBox(height: AppSpace.md),
                _SectionLabel(label: '已截止  ${overdue.length}'),
                const SizedBox(height: AppSpace.xs),
                for (final item in overdue.reversed)
                  _TodoTile(item: item, onTap: () => onOpen(item)),
              ],
            ];
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                pageX,
                AppSpace.sm,
                pageX,
                AppSpace.xl,
              ),
              itemCount: rows.length,
              itemBuilder: (_, i) => rows[i],
            );
          },
        ),
      ),
    );
    if (!showToolbar) return content;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pageX, 4, pageX, 4),
          child: Row(
            children: [
              if (MediaQuery.sizeOf(context).width >=
                      AppLayout.shellBreakpoint &&
                  ShellTabScope.maybeOf(context) != null)
                const Spacer()
              else ...[
                Icon(Icons.person_outline_rounded, size: 17, color: p.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ref.watch(rollcallAccountNameProvider),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: p.ink,
                    ),
                  ),
                ),
              ],
              const _HomeworkRefreshAction(),
            ],
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}

class _HomeworkRefreshAction extends ConsumerWidget {
  const _HomeworkRefreshAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updatedAt = ref.read(homeworkTodosProvider.notifier).lastUpdatedAt;
    return AppRefreshButton(
      key: const ValueKey('homework-refresh'),
      tooltip: updatedAt == null
          ? '刷新作业'
          : '刷新作业，上次更新 ${updatedAt.toLocal().toString().substring(5, 16)}',
      onRefresh: () => _refreshHomework(ref),
      color: AppPalette.of(context).muted,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TeachingCourseCard extends ConsumerWidget {
  const _TeachingCourseCard({required this.course, required this.onOpen});
  final CatalogCourse course;
  final ValueChanged<HomeworkItem> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(course.id);
    if (id == null) return const SizedBox.shrink();
    final p = AppPalette.of(context);
    final async = ref.watch(courseHomeworkProvider(id));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Text(
                  course.isInstructor ? '教学课程' : '助教课程',
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: p.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Panel(
            padding: EdgeInsets.zero,
            child: async.when(
              skipLoadingOnReload: false,
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LinearProgressIndicator(minHeight: 2),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '暂时无法更新课程作业',
                        style: TextStyle(fontSize: 12, color: p.muted),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(courseHomeworkProvider(id).notifier)
                          .refresh(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                final open = items.where((i) => !i.isOverdue).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (open.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '当前没有进行中的作业',
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                      ),
                    for (var i = 0; i < open.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: p.border,
                          indent: 16,
                          endIndent: 16,
                        ),
                      _TeachingAssignmentRow(
                        item: open[i],
                        onTap: () =>
                            onOpen(open[i].copyWith(courseName: course.title)),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TeachingAssignmentRow extends StatelessWidget {
  const _TeachingAssignmentRow({required this.item, required this.onTap});
  final HomeworkItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final due = item.dueAt?.toLocal();
    final dueLabel = due == null
        ? '无截止日期'
        : '${due.year == DateTime.now().year ? '' : '${due.year}/'}${due.month}/${due.day} '
              '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')} 截止';
    return AppHoverSurface(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      outlined: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.isEmpty ? '未命名作业' : item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(dueLabel, style: TextStyle(fontSize: 12, color: p.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, size: 18, color: p.muted),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: p.muted,
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({required this.item, required this.onTap});

  final HomeworkItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpace.stackOf(context) * 0.55),
      child: AppHoverSurface(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isEmpty ? '未命名作业' : item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      height: 1.3,
                      color: p.ink,
                    ),
                  ),
                  if (item.courseName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: p.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  HomeworkStatusBadges(item: item, withDeadline: true),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
          ],
        ),
      ),
    );
  }
}
