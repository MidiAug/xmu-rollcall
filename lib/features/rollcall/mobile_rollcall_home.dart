import 'package:xmu_rollcall/features/location/course_meeting.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/pull_to_refresh.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/network/request_failure.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/campus/campus_context_panel.dart';
import 'package:xmu_rollcall/features/campus/campus_summary.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/history/history_summary.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_quick_control.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

/// Mobile presentation of the existing scoped providers, not a second data flow.
class MobileRollcallHome extends ConsumerStatefulWidget {
  const MobileRollcallHome({
    super.key,
    required this.controller,
    required this.accountMenu,
    required this.scope,
    required this.updatedLabel,
    this.outsideDetectionWindow = false,
    required this.onHistory,
    required this.onSettings,
    required this.onTimetable,
    required this.onHomework,
    required this.onOpenHomework,
    this.switching = false,
    this.switchError,
    required this.onRetryIdentity,
  });
  final ScrollController controller;
  final Widget accountMenu;
  final int? scope;
  final String updatedLabel;
  final bool outsideDetectionWindow;
  final VoidCallback onHistory,
      onSettings,
      onTimetable,
      onHomework,
      onRetryIdentity;
  final ValueChanged<HomeworkItem> onOpenHomework;
  final bool switching;
  final String? switchError;

  @override
  ConsumerState<MobileRollcallHome> createState() => _MobileRollcallHomeState();
}

class _MobileRollcallHomeState extends ConsumerState<MobileRollcallHome>
    with ShellTabAware<MobileRollcallHome> {
  bool _checked = false;
  (int?, int?)? _identity;
  @override
  AppDestination get shellTab => AppDestination.rollcall;
  @override
  void onShellTabHidden() {
    super.onShellTabHidden();
    _checked = false;
  }

  @override
  void onShellTabRetap() {
    super.onShellTabRetap();
    setState(() => _checked = false);
  }

  Widget _headerIcon(String label, IconData icon, VoidCallback action) {
    final android = Theme.of(context).platform == TargetPlatform.android;
    final p = AppPalette.of(context);
    return SizedBox(
      width: android ? 44 : null,
      height: android ? 48 : null,
      child: IconButton(
        tooltip: label,
        alignment: android ? Alignment.topRight : Alignment.center,
        padding: android ? const EdgeInsets.only(top: 4) : null,
        constraints: android
            ? const BoxConstraints.tightFor(width: 44, height: 48)
            : null,
        onPressed: action,
        icon: Icon(icon, color: android ? p.muted : p.ink, size: 23),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final accountMenu = widget.accountMenu;
    final scope = widget.scope;
    final updatedLabel = widget.updatedLabel;
    final outsideDetectionWindow = widget.outsideDetectionWindow;
    final onHistory = widget.onHistory;
    final onSettings = widget.onSettings;
    final onTimetable = widget.onTimetable;
    final onHomework = widget.onHomework;
    final onOpenHomework = widget.onOpenHomework;
    final switching = widget.switching;
    final switchError = widget.switchError;
    final onRetryIdentity = widget.onRetryIdentity;
    final identity = (
      ref.watch(authControllerProvider.select((s) => s.profile?.id)),
      scope,
    );
    if (_identity != identity) {
      _identity = identity;
      _checked = false;
    }

    final p = AppPalette.of(context);
    final android = Theme.of(context).platform == TargetPlatform.android;
    final signedIn = ref.watch(
      authControllerProvider.select((s) => s.isSignedIn),
    );
    final now =
        ref.watch(campusClockProvider).valueOrNull ??
        ref.read(campusNowProvider)();
    final cached = signedIn ? ref.watch(campusCachedDataProvider) : null;
    // A refresh or identity transition must not show stale scoped data.
    final data =
        (cached?.isLoading == true ? null : cached?.valueOrNull) ??
        const CampusCachedData();
    final active = signedIn && !switching && switchError == null
        ? ref.watch(activeRollcallsProvider(scope))
        : null;
    final items = active?.valueOrNull ?? const [];
    final running = ref.watch(
      monitorControllerProvider.select((s) => s.running),
    );
    final checking = switching || (active?.isLoading == true && items.isEmpty);
    final headerStatus = !signedIn
        ? '登录后查看课堂签到'
        : checking
        ? '正在确认最新状态…'
        : switchError ??
              (active?.hasError == true
                  ? '暂时无法确认签到状态'
                  : _checked && items.isEmpty
                  ? '暂无正在签到的课程'
                  : outsideDetectionWindow
                  ? updatedLabel
                  : items.isEmpty
                  ? '尚未开始检测'
                  : updatedLabel);
    final Widget headerAction = !signedIn
        ? FilledButton(
            onPressed: () => showLoginDialog(context),
            child: const Text('登录'),
          )
        : running
        ? const MonitorQuickControl(style: MonitorControlStyle.mastheadQuiet)
        : checking
        ? const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        : switchError != null
        ? TextButton(onPressed: onRetryIdentity, child: const Text('重试'))
        : MonitorQuickControl(
            style: items.isEmpty
                ? MonitorControlStyle.masthead
                : MonitorControlStyle.mastheadQuiet,
          );
    final history = signedIn && !android
        ? ref.watch(currentCourseHistoryProvider)
        : null;
    final records = history?.isLoading == false ? history?.valueOrNull : null;
    final latest = HistorySummary(records ?? []).records.firstOrNull;
    final time = latest?.rollcallTime?.toLocal();
    final historyText = latest == null
        ? '暂无签到历史'
        : '${time == null ? '' : '${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}  '}'
              '${historyAttendance(latest) == HistoryAttendance.signed
                  ? '已签到'
                  : historyAttendance(latest) == HistoryAttendance.unsigned
                  ? '未签到'
                  : latest.signedStatus}';
    Widget inset(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: child,
    );
    return ColoredBox(
      color: p.mobileCanvas,
      child: AppPullToRefresh(
        color: p.primary,
        onRefresh: () async {
          if (signedIn && !switching && switchError == null) {
            setState(() => _checked = false);
            await ref.read(activeRollcallsProvider(scope).notifier).refresh();
            if (mounted &&
                _identity == identity &&
                !ref.read(activeRollcallsProvider(scope)).hasError) {
              setState(() => _checked = true);
            }
          }
        },
        child: CustomScrollView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                key: const ValueKey('mobile-rollcall-header'),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: accountMenu),
                        _headerIcon('签到记录', AppIcons.history, onHistory),
                        _headerIcon('自动检测设置', AppIcons.settings, onSettings),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${now.month}月${now.day}日 周${'一二三四五六日'[now.weekday - 1]}',
                      key: const ValueKey('mobile-home-date'),
                      style: AppTypography.body.copyWith(color: p.muted),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 60),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  running
                                      ? '值守中'
                                      : items.isNotEmpty &&
                                            switchError == null &&
                                            active?.hasError != true
                                      ? '待签到'
                                      : headerStatus,
                                  key: !running && android
                                      ? const ValueKey(
                                          'android-detection-status',
                                        )
                                      : null,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: switchError == null
                                        ? p.ink
                                        : p.danger,
                                  ),
                                ),
                                if (running) ...[
                                  const SizedBox(height: 4),
                                  const MonitorQuickControl(
                                    style: MonitorControlStyle.mastheadStatus,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        headerAction,
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: inset(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: android ? 0 : 20),
                    ...[
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RollcallTaskCard(
                            key: ValueKey((scope, item.rollcallId)),
                            item: item,
                            assistUserId: scope,
                            meeting: data.schedule == null
                                ? null
                                : selectCampusMeetingForTitle(
                                    data.schedule!,
                                    radarActivityReferenceTime(item, now),
                                    item.courseTitle,
                                  ),
                            mobileSummary: updatedLabel,
                          ),
                        ),
                      if (active?.hasError == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  requestFailureMessage(active!.error!),
                                  style: TextStyle(
                                    color: p.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => ref
                                    .read(
                                      activeRollcallsProvider(scope).notifier,
                                    )
                                    .refresh(),
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (signedIn) ...[
                      const SizedBox(height: 20),
                      KeyedSubtree(
                        key: const ValueKey('mobile-context-surface'),
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: CampusContextView(
                            data: data,
                            now: now,
                            mobile: true,
                            showHomework: !android,
                            loading: cached?.isLoading == true,
                            onTimetable: onTimetable,
                            onHomework: onHomework,
                            onOpenHomework: onOpenHomework,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!android)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                    child: signedIn
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Divider(color: p.borderStrong, height: 1),
                              AppHoverSurface(
                                quiet: true,
                                outlined: false,
                                backgroundColor: Colors.transparent,
                                hoverColor: p.cardHover,
                                pressedColor: p.hover,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.control,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                onTap: onHistory,
                                child: Row(
                                  children: [
                                    Icon(
                                      AppIcons.history,
                                      size: 18,
                                      color: p.muted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '上次签到  $historyText',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: p.muted,
                                          fontSize: 12,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(AppIcons.right),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
