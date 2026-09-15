import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

/// 签到 Tab：进行中列表为主；轮询为快开子功能 + 二级设置。
class RollcallHubPage extends ConsumerStatefulWidget {
  const RollcallHubPage({super.key});

  @override
  ConsumerState<RollcallHubPage> createState() => _RollcallHubPageState();
}

class _RollcallHubPageState extends ConsumerState<RollcallHubPage>
    with ShellTabAware<RollcallHubPage> {
  final _scroll = ScrollController();

  @override
  AppDestination get shellTab => AppDestination.rollcall;

  @override
  ScrollController? get shellScrollController => _scroll;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: AppMotion.duration,
        reverseTransitionDuration: AppMotion.duration,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MonitorSettingsPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: AppMotion.curve,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;
    final p = AppPalette.of(context);

    return PageScaffold(
      title: '签到',
      subtitle: '数字一键签 · 雷达/二维码二级页',
      showHeader: wide,
      trailing: wide
          ? AppRefreshButton(
              color: p.muted,
              onRefresh: () =>
                  ref.read(activeRollcallsProvider.notifier).refresh(),
            )
          : null,
      child: PrimaryScrollController(
        controller: _scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.pageXOf(context),
                wide ? 0 : AppSpace.xxs,
                AppSpace.pageXOf(context),
                AppSpace.sm,
              ),
              child: Row(
                children: [
                  const Expanded(child: _PollQuickBar()),
                  if (!wide) ...[
                    const SizedBox(width: AppSpace.xxs),
                    AppRefreshButton(
                      visualDensity: VisualDensity.compact,
                      color: p.muted,
                      iconSize: 22,
                      onRefresh: () =>
                          ref.read(activeRollcallsProvider.notifier).refresh(),
                    ),
                  ],
                  IconButton(
                    tooltip: '轮询设置',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openSettings(context),
                    icon: Icon(Icons.tune_outlined, color: p.muted, size: 22),
                  ),
                ],
              ),
            ),
            const Expanded(child: RollcallListPage(embedded: true)),
          ],
        ),
      ),
    );
  }
}

/// Idle: 「开始轮询」. Running: capsule with countdown (tap = pollNow) + stop.
class _PollQuickBar extends ConsumerStatefulWidget {
  const _PollQuickBar();

  @override
  ConsumerState<_PollQuickBar> createState() => _PollQuickBarState();
}

class _PollQuickBarState extends ConsumerState<_PollQuickBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (ref.read(monitorControllerProvider).running) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final monitor = ref.watch(monitorControllerProvider);
    final ctrl = ref.read(monitorControllerProvider.notifier);
    final signedIn = ref.watch(authControllerProvider).isSignedIn;

    if (!monitor.running) {
      final enabled = signedIn;
      final color = enabled ? p.primary : p.muted;
      return Align(
        alignment: Alignment.centerLeft,
        child: Tooltip(
          message: enabled ? '开始轮询' : '请先登录',
          child: TextButton.icon(
            onPressed: enabled ? ctrl.start : null,
            icon: Icon(Icons.radar_outlined, size: 18, color: color),
            label: Text(
              '开始轮询',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      );
    }

    final next = monitor.nextPollAt;
    final secs = next == null
        ? 0
        : next.difference(DateTime.now()).inSeconds.clamp(0, 9999);
    final label = '轮询中 · ${secs}s';

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: p.selected,
            borderRadius: BorderRadius.circular(AppRadii.control),
            child: InkWell(
              onTap: ctrl.pollNow,
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '停止轮询',
            visualDensity: VisualDensity.compact,
            onPressed: ctrl.stop,
            icon: Icon(Icons.stop_circle_outlined, color: p.muted, size: 22),
          ),
        ],
      ),
    );
  }
}
