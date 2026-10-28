import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/mobile_campus_header.dart';
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
class MobileRollcallHome extends ConsumerWidget {
  const MobileRollcallHome({
    super.key,
    required this.controller,
    required this.accountMenu,
    required this.scope,
    required this.updatedLabel,
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
  final VoidCallback onHistory,
      onSettings,
      onTimetable,
      onHomework,
      onRetryIdentity;
  final ValueChanged<HomeworkItem> onOpenHomework;
  final bool switching;
  final String? switchError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final android = Theme.of(context).platform == TargetPlatform.android;
    final signedIn = ref.watch(authControllerProvider).isSignedIn;
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
    final running = ref.watch(monitorControllerProvider).running;
    final checking = switching || (active?.isLoading == true && items.isEmpty);
    final windowStatus =
        updatedLabel.contains('今日无课') ||
        updatedLabel.contains('时段') ||
        updatedLabel.contains('课程');
    final headerStatus = !signedIn
        ? '登录后查看课堂签到'
        : checking
        ? '正在确认最新状态…'
        : switchError ??
              (windowStatus
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
        ? const MonitorQuickControl(quiet: true)
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
            prominent: items.isEmpty,
            quiet: items.isNotEmpty,
          );
    final history = signedIn ? ref.watch(currentCourseHistoryProvider) : null;
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
            await ref.read(activeRollcallsProvider(scope).notifier).refresh();
          }
        },
        child: CustomScrollView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: MobileCampusHeader(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '签到',
                                style: TextStyle(
                                  fontSize: 28,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Semantics(
                                  label:
                                      '${now.month}月${now.day}日 周${'一二三四五六日'[now.weekday - 1]}',
                                  child: Text(
                                    MediaQuery.sizeOf(context).width < 360 ||
                                            MediaQuery.textScalerOf(
                                                  context,
                                                ).scale(1) >
                                                1.15
                                        ? '${now.month}/${now.day} 周${'一二三四五六日'[now.weekday - 1]}'
                                        : '${now.month}月${now.day}日 周${'一二三四五六日'[now.weekday - 1]}',
                                    key: const ValueKey('mobile-home-date'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: p.muted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '签到记录',
                          onPressed: onHistory,
                          icon: Icon(AppIcons.history, color: p.ink, size: 23),
                        ),
                        IconButton(
                          tooltip: '自动检测设置',
                          onPressed: onSettings,
                          icon: Icon(AppIcons.settings, color: p.ink, size: 23),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: android
                              ? 144
                              : items.isNotEmpty
                              ? 140
                              : 180,
                          child: accountMenu,
                        ),
                        if (android)
                          headerAction
                        else if (items.isNotEmpty)
                          const MonitorQuickControl(quiet: true),
                      ],
                    ),
                    if (android && !running) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: switchError != null
                                  ? p.danger
                                  : p.muted.withValues(alpha: .6),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: AppTruncatedText(
                              headerStatus,
                              key: const ValueKey('android-detection-status'),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: switchError != null ? p.danger : p.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                    if (!android && !signedIn)
                      _HomeStatus(
                        title: '登录后查看课堂签到',
                        action: FilledButton(
                          onPressed: () => showLoginDialog(context),
                          child: const Text('登录'),
                        ),
                      )
                    else if (!android && checking)
                      const _HomeStatus(
                        title: '正在确认最新状态…',
                        action: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (!android && switchError != null)
                      _HomeStatus(
                        title: switchError!,
                        action: TextButton(
                          onPressed: onRetryIdentity,
                          child: const Text('重试'),
                        ),
                      )
                    else ...[
                      if (!android && items.isEmpty)
                        _HomeStatus(
                          title: running ? '正在检测签到' : '尚未开始检测',
                          detail:
                              updatedLabel.contains('今日无课') ||
                                  updatedLabel.contains('时段') ||
                                  updatedLabel.contains('课程')
                              ? updatedLabel
                              : running
                              ? null
                              : '暂无进行中的签到',
                          action: const MonitorQuickControl(prominent: true),
                        ),
                      if (android && items.isNotEmpty)
                        const SizedBox(height: 20),
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
                                    now,
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
                      DecoratedBox(
                        key: const ValueKey('mobile-context-surface'),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: CampusContextView(
                            data: data,
                            now: now,
                            mobile: true,
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
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onHistory,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
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
                                      Icon(
                                        AppIcons.right,
                                        size: 16,
                                        color: p.muted,
                                      ),
                                    ],
                                  ),
                                ),
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

class _HomeStatus extends StatelessWidget {
  const _HomeStatus({required this.title, required this.action, this.detail});
  final String title;
  final String? detail;
  final Widget action;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.15;
          final caption = Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: p.muted.withValues(alpha: .6),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
              ),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stacked) ...[
                caption,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: action),
              ] else
                Row(
                  children: [
                    Expanded(child: caption),
                    const SizedBox(width: 12),
                    action,
                  ],
                ),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail!,
                  style: TextStyle(fontSize: 12, color: p.muted, height: 1.5),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
