import 'package:xmu_rollcall/features/monitor/detection_window_setting.dart';
import 'package:xmu_rollcall/features/history/history_summary.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/monitor/monitor_quick_control.dart';
import 'package:xmu_rollcall/app/desktop/desktop_workspace.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/app/shell_navigation.dart';
import 'package:xmu_rollcall/features/campus/campus_context_panel.dart';
import 'package:xmu_rollcall/features/settings/courses_page.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account_menu.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/history/history_page.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

/// 签到 Tab：进行中列表为主；轮询为快开子功能 + 二级设置；记录为二级页。
class RollcallHubPage extends ConsumerStatefulWidget {
  const RollcallHubPage({super.key});

  @override
  ConsumerState<RollcallHubPage> createState() => _RollcallHubPageState();
}

class _RollcallHubPageState extends ConsumerState<RollcallHubPage>
    with ShellTabAware<RollcallHubPage>, WidgetsBindingObserver {
  final _scroll = ScrollController();
  int? get _assistUserId => ref.read(selectedRollcallAccountProvider);
  bool _switching = false;
  String? _switchError;
  int _switchRevision = 0;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _confirmOnAppear() {
    if (!mounted ||
        !_visible ||
        _switching ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) ||
        !ref.read(authControllerProvider).isSignedIn) {
      return;
    }
    final monitor = ref.read(monitorControllerProvider);
    if (monitor.running || monitor.starting || monitor.loadingSettings) {
      AppLog.event(
        'rollcall.appear.skipped',
        fields: {'reason': 'monitor_owns_refresh'},
      );
      return;
    }
    unawaited(
      ref
          .read(activeRollcallsProvider(_assistUserId).notifier)
          .ensureFreshOnAppear(),
    );
  }

  @override
  void onShellTabVisible() {
    super.onShellTabVisible();
    _visible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _confirmOnAppear());
  }

  @override
  void onShellTabHidden() {
    _visible = false;
    super.onShellTabHidden();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _confirmOnAppear();
  }

  Future<void> _selectIdentity(int value) async {
    final id = value == 0 ? null : value;
    if (ref.read(selectedRollcallAccountProvider) != id) {
      ref.read(selectedRollcallAccountProvider.notifier).state = id;
      return;
    }
    await _loadIdentity(id);
  }

  Future<void> _loadIdentity(int? id) async {
    final revision = ++_switchRevision;
    setState(() {
      _switching = id != null;
      _switchError = null;
    });
    AppLog.event(
      'rollcall.identity.switch',
      fields: {'session': id == null ? 'owner' : 'assist', 'assistUserId': ?id},
    );
    if (id == null) return;
    try {
      final identity = ref
          .read(assistControllerProvider)
          .identities
          .firstWhere((e) => e.userId == id);
      final service = await ref.read(assistServiceProvider.future);
      await service.ensureSession(identity);
      final healed = await service.ensureDeviceId(identity);
      if (!mounted || revision != _switchRevision) return;
      ref.read(assistControllerProvider.notifier).updateIdentity(healed);
      unawaited(
        ref.read(academicSyncProvider).sync(id).catchError((Object _) {}),
      );
      // Reload even when this identity already has a cached list.
      await ref.read(activeRollcallsProvider(id).notifier).refresh();
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'rollcall.identity.switch',
      );
      if (!mounted || revision != _switchRevision) return;
      setState(() => _switchError = '无法加载该身份，请重试');
    } finally {
      if (mounted && revision == _switchRevision) {
        setState(() => _switching = false);
      }
    }
  }

  @override
  AppDestination get shellTab => AppDestination.rollcall;

  @override
  ScrollController? get shellScrollController => _scroll;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  void _openSettings(BuildContext context) {
    AppPageRoutes.push(context, const MonitorSettingsPage());
  }

  void _openHistory(BuildContext context) {
    AppPageRoutes.push(context, const HistoryPage());
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;
    final p = AppPalette.of(context);
    final auth = ref.watch(authControllerProvider);
    final roster = ref.watch(assistControllerProvider).identities;
    final selected = ref.watch(selectedRollcallAccountProvider);
    final scope = roster.any((e) => e.userId == selected) ? selected : null;
    final planned = ref.watch(selectedDetectionWindowProvider);
    final window = planned.isLoading ? null : planned.valueOrNull;
    final outsideWindow =
        window != null &&
        !window.allows(ref.read(activeRollcallClockProvider)());
    DateTime? updatedAt;
    var confirming = false;
    if (auth.isSignedIn && !_switching && _switchError == null) {
      confirming = ref.watch(activeRollcallsProvider(scope)).isLoading;
      updatedAt = ref
          .read(activeRollcallsProvider(scope).notifier)
          .lastUpdatedAt;
    }
    final updatedLabel = outsideWindow
        ? (window.scheduleBased
              ? detectionStatusLabel(
                  window,
                  ref.read(activeRollcallClockProvider)(),
                )
              : '时段外暂停获取签到（${window.label}）')
        : _switching
        ? '正在切换…'
        : confirming
        ? '正在确认最新状态…'
        : updatedAt == null
        ? '下拉刷新签到'
        : '更新于 ${updatedAt.toLocal().toString().substring(11, 19)}';
    ref.listen(selectedRollcallAccountProvider, (previous, next) {
      if (previous != next) unawaited(_loadIdentity(next));
    });
    ref.listen(authControllerProvider.select((state) => state.profile?.id), (
      previous,
      next,
    ) {
      if (previous == next) return;
      _switchRevision++;
      setState(() {
        _switching = false;
        _switchError = null;
      });
    });
    ref.listen(assistControllerProvider, (previous, next) {
      if (next.ready &&
          _assistUserId != null &&
          !next.identities.any((e) => e.userId == _assistUserId)) {
        _switchRevision++;
        setState(() {
          ref.read(selectedRollcallAccountProvider.notifier).state = null;
          _switching = false;
          _switchError = null;
        });
      }
    });

    if (PlatformHooks.isDesktop && !AppDensity.isTouch(context)) {
      final active =
          ShellTabScope.maybeOf(context)?.isActive(AppDestination.rollcall) ??
          true;
      final pendingCount = auth.isSignedIn
          ? (ref.watch(activeRollcallsProvider(scope)).valueOrNull ??
                    const <RollcallItem>[])
                .where((item) => !item.isAnswered && !item.isExpired)
                .length
          : 0;
      final cached = active && auth.isSignedIn
          ? ref
                .watch(campusCachedDataProvider)
                .whenOrNull(skipLoadingOnReload: false, data: (data) => data)
          : null;
      final now = active && auth.isSignedIn
          ? ref.watch(campusClockProvider).valueOrNull ??
                ref.read(campusNowProvider)()
          : DateTime.now();
      final records = auth.isSignedIn
          ? ref
                    .watch(currentCourseHistoryProvider)
                    .whenOrNull(
                      skipLoadingOnReload: false,
                      data: (data) => data,
                    ) ??
                const <CourseRollcallRecord>[]
          : const <CourseRollcallRecord>[];
      final history = HistorySummary(records).records;
      final latest = history.isEmpty ? null : history.first;
      final latestAt = latest?.rollcallTime?.toLocal();
      final latestSigned =
          latest != null &&
          historyAttendance(latest) == HistoryAttendance.signed;
      final historyLink = auth.isSignedIn
          ? Column(
              key: const ValueKey('latest-history-footer'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(color: p.border, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: latest == null
                            ? const SizedBox.shrink()
                            : Row(
                                children: [
                                  Text(
                                    '上次签到',
                                    style: TextStyle(
                                      color: p.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: latestSigned
                                          ? p.successSurface
                                          : p.surfaceHigh,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      latestSigned
                                          ? AppIcons.check
                                          : AppIcons.history,
                                      size: 20,
                                      color: latestSigned
                                          ? p.successAccent
                                          : p.muted,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      latest.courseTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.control.copyWith(
                                        color: p.ink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    latestAt == null
                                        ? '时间未提供'
                                        : '${latestAt.year == now.year && latestAt.month == now.month && latestAt.day == now.day ? '今天' : '${latestAt.month}/${latestAt.day}'} ${latestAt.hour.toString().padLeft(2, '0')}:${latestAt.minute.toString().padLeft(2, '0')}',
                                    style: AppTypography.caption.copyWith(
                                      color: p.muted,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AppStatusBadge(
                                    latest.signedStatus.isEmpty
                                        ? '状态未知'
                                        : latest.signedStatus,
                                    tone: latestSigned
                                        ? AppStatusTone.success
                                        : AppStatusTone.danger,
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 12),
                      AppTextLink(
                        '查看记录',
                        onPressed: () => _openHistory(context),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : null;
      return DesktopWorkspace(
        title: '签到',
        subtitle:
            '${now.month}月${now.day}日  ${const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][now.weekday - 1]}',
        actions: [
          if (!(ShellTabScope.maybeOf(context)?.hasGlobalIdentityControl ??
              false))
            RollcallAccountMenu(
              width: 140,
              value: scope ?? 0,
              identities: roster,
              ownerName: auth.profile?.name ?? '我',
              onChanged: _selectIdentity,
            ),
          const MonitorQuickControl(toolbar: true),
          AppRefreshButton(
            key: ValueKey((auth.profile?.id, scope)),
            iconSize: 20,
            onRefresh: () async {
              if (_switching) return;
              if (_switchError != null) {
                await _selectIdentity(scope ?? 0);
              } else {
                await ref
                    .read(activeRollcallsProvider(scope).notifier)
                    .refresh();
              }
            },
          ),
          IconButton(
            tooltip: '签到记录',
            style: IconButton.styleFrom(
              minimumSize: const Size(34, 34),
              padding: const EdgeInsets.all(7),
              backgroundColor: p.surface,
              side: BorderSide(color: p.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            onPressed: () => _openHistory(context),
            icon: const Icon(AppIcons.history, size: 20),
          ),
          IconButton(
            tooltip: '签到设置',
            style: IconButton.styleFrom(
              minimumSize: const Size(34, 34),
              padding: const EdgeInsets.all(7),
              backgroundColor: p.surface,
              side: BorderSide(color: p.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            onPressed: () => _openSettings(context),
            icon: const Icon(AppIcons.settings, size: 20),
          ),
        ],
        contextPanel: active && auth.isSignedIn
            ? CampusContextPanel(
                onTimetable: () {
                  if (scope == null) {
                    ShellNavigation.instance.open(AppDestination.timetable);
                  } else {
                    AppPageRoutes.push(
                      context,
                      CoursesPage(assistUserId: scope),
                    );
                  }
                },
                onHomework: () =>
                    ShellNavigation.instance.open(AppDestination.homework),
                onOpenHomework: (item) =>
                    AppPageRoutes.push(context, HomeworkDetailPage(seed: item)),
              )
            : null,
        child: PrimaryScrollController(
          controller: _scroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: pendingCount > 0 ? p.successAccent : p.muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pendingCount > 0 && !outsideWindow
                            ? '已发现 $pendingCount 项待签到'
                            : updatedLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: pendingCount > 0 ? p.ink : p.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _switching
                    ? const Center(child: CircularProgressIndicator())
                    : _switchError != null
                    ? EmptyHint(
                        icon: AppIcons.person,
                        title: _switchError!,
                        action: TextButton(
                          onPressed: () => _selectIdentity(scope ?? 0),
                          child: const Text('重试'),
                        ),
                      )
                    : RollcallListPage(
                        key: ValueKey(scope),
                        embedded: true,
                        showUpdatedAt: false,
                        assistUserId: scope,
                        academicSchedule: cached?.schedule,
                        at: now,
                      ),
              ),
              if (historyLink != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: historyLink,
                ),
            ],
          ),
        ),
      );
    }

    return PageScaffold(
      title: '签到',
      showHeader: false,
      child: AppContentColumn(
        child: PrimaryScrollController(
          controller: _scroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.pageXOf(context),
                  wide ? AppSpace.sm : AppSpace.xs,
                  AppSpace.pageXOf(context),
                  AppSpace.sm,
                ),
                child: DecoratedBox(
                  key: const ValueKey('rollcall-toolbar'),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(AppRadii.group),
                    border: Border.all(color: p.mobileOutline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child:
                                  wide && ShellTabScope.maybeOf(context) != null
                                  ? const MonitorQuickControl()
                                  : RollcallAccountMenu(
                                      value: scope ?? 0,
                                      identities: roster,
                                      ownerName: auth.profile?.name ?? '我',
                                      onChanged: _selectIdentity,
                                    ),
                            ),
                            const SizedBox(width: 4),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: '签到记录',
                              style: AppControlStyle.touchIcon(context),
                              visualDensity: VisualDensity.standard,
                              onPressed: () => _openHistory(context),
                              icon: Icon(
                                AppIcons.history,
                                color: p.muted,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: '自动检测设置',
                              style: AppControlStyle.touchIcon(context),
                              visualDensity: VisualDensity.standard,
                              onPressed: () => _openSettings(context),
                              icon: Icon(
                                AppIcons.settings,
                                color: p.muted,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                updatedLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: p.muted),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!wide || ShellTabScope.maybeOf(context) == null)
                              const MonitorQuickControl(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _switching
                    ? const Center(child: CircularProgressIndicator())
                    : _switchError != null
                    ? EmptyHint(
                        icon: AppIcons.person,
                        title: _switchError!,
                        action: TextButton(
                          onPressed: () => _selectIdentity(scope ?? 0),
                          child: const Text('重试'),
                        ),
                      )
                    : RollcallListPage(
                        key: ValueKey(scope),
                        embedded: true,
                        showUpdatedAt: false,
                        assistUserId: scope,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
