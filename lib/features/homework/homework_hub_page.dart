import 'homework_list_row.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
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
  final refreshed = await ref
      .read(homeworkOverviewProvider.notifier)
      .ensureFresh(force: force);
  if (!force && !refreshed) return;
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
  _TaskFilter _filter = _TaskFilter.all;

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
    if (!ref.read(authControllerProvider).isSignedIn) return;
    await _refreshHomework(ref, force: false, refreshStatuses: refreshStatuses);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    _foreground = state == AppLifecycleState.resumed;
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
  void onShellTabRetap() {
    super.onShellTabRetap();
    setState(() => _filter = _TaskFilter.all);
  }

  @override
  AppDestination get shellTab => AppDestination.homework;

  @override
  ScrollController? get shellScrollController => _scroll;

  @override
  void onShellTabVisible() {
    super.onShellTabVisible();
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

  void _changeFilter(_TaskFilter filter) {
    if (filter == _filter) return;
    // A new result scope starts at its first item. Detail navigation keeps the
    // same scroll position because it does not pass through this action.
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _filter = filter);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authControllerProvider).isSignedIn;
    final active =
        ShellTabScope.maybeOf(context)?.isActive(AppDestination.homework) ??
        true;

    final hostActions = PlatformHooks.isDesktop && !AppDensity.isTouch(context);
    return PageScaffold(
      title: '作业',
      showHeader: false,
      child: AppPageViewport(
        maxWidth: AppLayout.workspaceMaxWidth,
        builder: (context, contentInsets) => PrimaryScrollController(
          controller: _scroll,
          child: !signedIn
              ? _SignedOutHint(onLogin: () => showLoginDialog(context))
              : active
              ? _TodosBody(
                  contentInsets: contentInsets,
                  onOpen: _openDetail,
                  showToolbar:
                      hostActions ||
                      (Theme.of(context).platform != TargetPlatform.android &&
                          Theme.of(context).platform != TargetPlatform.iOS),
                  filter: _filter,
                  onFilterChanged: _changeFilter,
                )
              : const SizedBox.shrink(),
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
        icon: const Icon(AppIcons.login, size: 18),
        label: const Text('登录'),
      ),
    );
  }
}

enum _TaskFilter { all, upcoming, overdue }

class _TodosBody extends ConsumerStatefulWidget {
  const _TodosBody({
    required this.onOpen,
    this.contentInsets = EdgeInsets.zero,
    required this.showToolbar,
    required this.filter,
    required this.onFilterChanged,
  });
  final _TaskFilter filter;
  final ValueChanged<_TaskFilter> onFilterChanged;
  final EdgeInsets contentInsets;
  final bool showToolbar;
  final ValueChanged<HomeworkItem> onOpen;
  @override
  ConsumerState<_TodosBody> createState() => _TodosBodyState();
}

class _TodosBodyState extends ConsumerState<_TodosBody> {
  _TaskFilter get _filter => widget.filter;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final pageX = AppSpace.pageXOf(context);
    final desktop = PlatformHooks.isDesktop && !AppDensity.isTouch(context);
    final contentInsets = widget.contentInsets;
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
            primary: true,
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
                primary: true,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: const [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyHint(
                      icon: Icons.assignment_turned_in_outlined,
                      title: '暂无作业',
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
              if (desktop &&
                  ((_filter == _TaskFilter.upcoming && upcoming.isEmpty) ||
                      (_filter == _TaskFilter.overdue && overdue.isEmpty)))
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '当前分组暂无作业',
                    style: AppTypography.body.copyWith(color: p.muted),
                  ),
                ),
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
                  _TeachingCourseCard(course: course, onOpen: widget.onOpen),
                if (studentItems.isNotEmpty)
                  const SizedBox(height: AppSpace.md),
              ],
              if (upcoming.isNotEmpty && (_filter != _TaskFilter.overdue)) ...[
                SettingsSection(
                  headerStyle: AppTypography.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                  header: '进行中  ${upcoming.length}',
                  dividerIndent: HomeworkListRow.titleInset(context),
                  padTop: false,
                  children: [
                    for (final item in upcoming)
                      _TodoTile(item: item, onTap: () => widget.onOpen(item)),
                  ],
                ),
              ],
              if (overdue.isNotEmpty && (_filter != _TaskFilter.upcoming)) ...[
                if (upcoming.isNotEmpty) const SizedBox(height: AppSpace.md),
                SettingsSection(
                  headerStyle: AppTypography.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                  header: '已截止  ${overdue.length}',
                  dividerIndent: HomeworkListRow.titleInset(context),
                  padTop: false,
                  children: [
                    for (final item in overdue.reversed)
                      _TodoTile(item: item, onTap: () => widget.onOpen(item)),
                  ],
                ),
              ],
            ];
            return ListView.builder(
              // Desktop ScrollViews do not inherit a primary controller by
              // default; bind it explicitly so filters and tab re-taps use
              // the same live position as the visible list.
              primary: true,
              physics: const AlwaysScrollableScrollPhysics(),
              padding:
                  contentInsets +
                  EdgeInsets.fromLTRB(pageX, AppSpace.sm, pageX, AppSpace.xl),
              itemCount: rows.length,
              itemBuilder: (_, i) => rows[i],
            );
          },
        ),
      ),
    );

    return Column(
      children: [
        Padding(
          padding:
              contentInsets +
              EdgeInsets.symmetric(
                horizontal: pageX,
                vertical: desktop ? AppSpace.md : 4,
              ),
          child: Row(
            children: [
              if (desktop || !widget.showToolbar) ...[
                if (desktop)
                  _HomeworkFilters(
                    value: widget.filter,
                    onChanged: widget.onFilterChanged,
                  )
                else
                  Expanded(
                    child: _HomeworkFilters(
                      value: widget.filter,
                      onChanged: widget.onFilterChanged,
                    ),
                  ),
                if (widget.showToolbar) const Spacer(),
              ] else if (MediaQuery.sizeOf(context).width >=
                      AppLayout.shellBreakpoint &&
                  ShellTabScope.maybeOf(context) != null)
                const Spacer()
              else ...[
                Icon(AppIcons.person, size: 17, color: p.muted),
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
              if (widget.showToolbar)
                KeyedSubtree(
                  key: ValueKey((
                    ref.watch(authControllerProvider).profile?.id,
                    ref.watch(selectedRollcallAccountProvider),
                  )),
                  child: const _HomeworkRefreshAction(),
                ),
            ],
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}

class _HomeworkFilters extends ConsumerWidget {
  const _HomeworkFilters({required this.value, required this.onChanged});
  final _TaskFilter value;
  final ValueChanged<_TaskFilter> onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teaching =
        ref.watch(currentTeachingCoursesProvider).valueOrNull ??
        const <CatalogCourse>[];
    final ids = teaching.map((c) => c.id).toSet();
    final items =
        (ref.watch(homeworkOverviewProvider).valueOrNull?.items ??
                ref.watch(homeworkTodosProvider).valueOrNull ??
                const <HomeworkItem>[])
            .where((i) => !ids.contains('${i.courseId}'))
            .toList();
    return AppSegmentedControl<_TaskFilter>(
      value: value,
      trackOnTouch: true,
      expanded: AppDensity.isTouch(context),
      onChanged: onChanged,
      segments: [
        AppSegment(value: _TaskFilter.all, label: '全部 ${items.length}'),
        AppSegment(
          value: _TaskFilter.upcoming,
          label: '进行中 ${items.where((i) => !i.isOverdue).length}',
        ),
        AppSegment(
          value: _TaskFilter.overdue,
          label: '已截止 ${items.where((i) => i.isOverdue).length}',
        ),
      ],
    );
  }
}

class _HomeworkRefreshAction extends ConsumerWidget {
  const _HomeworkRefreshAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(homeworkTodosProvider);
    final updatedAt = ref.read(homeworkTodosProvider.notifier).lastUpdatedAt;
    return AppRefreshButton(
      key: const ValueKey('homework-refresh'),
      extent: 44,
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
    final noOpenItems =
        async.whenOrNull(
          skipLoadingOnReload: false,
          data: (items) => items.every((item) => item.isOverdue),
        ) ??
        false;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeading(
            key: noOpenItems ? ValueKey('teaching-empty-$id') : null,
            child: LayoutBuilder(
              builder: (context, bounds) {
                final scale = MediaQuery.textScalerOf(context).scale(1);
                final wrapStatus = bounds.maxWidth < 400 * scale;
                final heading = Row(
                  children: [
                    Text(course.isInstructor ? '教学课程' : '助教课程'),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: AppTruncatedText(
                        course.title,
                        style: DefaultTextStyle.of(
                          context,
                        ).style.copyWith(color: p.ink),
                      ),
                    ),
                    if (noOpenItems && !wrapStatus) ...[
                      const SizedBox(width: AppSpace.md),
                      Text(
                        '暂无进行中作业',
                        style: AppTypography.caption.copyWith(color: p.muted),
                      ),
                    ],
                  ],
                );
                if (!noOpenItems || !wrapStatus) return heading;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      '暂无进行中作业',
                      style: AppTypography.caption.copyWith(color: p.muted),
                    ),
                  ],
                );
              },
            ),
          ),
          if (!noOpenItems)
            SettingsSection(
              headerStyle: AppTypography.body.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
              padTop: false,
              children: [
                async.when(
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
                              indent: HomeworkListRow.titleInset(context),
                              endIndent: 16,
                            ),
                          _TeachingAssignmentRow(
                            item: open[i],
                            onTap: () => onOpen(
                              open[i].copyWith(courseName: course.title),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
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
    return HomeworkListRow(
      item: item,
      subtitle: '',
      onTap: onTap,
      compactTrailing: HomeworkStatusBadges(item: item, compact: true),
      trailing: HomeworkStatusBadges(
        item: item,
        withDeadline: true,
        compact: true,
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
    return HomeworkListRow(
      item: item,
      subtitle: item.courseName,
      onTap: onTap,
      compactTrailing: HomeworkStatusBadges(item: item, compact: true),
      trailing: HomeworkStatusBadges(
        item: item,
        withDeadline: true,
        compact: true,
      ),
    );
  }
}
