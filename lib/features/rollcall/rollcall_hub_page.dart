import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

enum RollcallHubSegment { active, poll }

/// 签到 Tab：进行中列表 + 轮询（原独立监控 Tab）。
class RollcallHubPage extends ConsumerStatefulWidget {
  const RollcallHubPage({super.key});

  @override
  ConsumerState<RollcallHubPage> createState() => _RollcallHubPageState();
}

class _RollcallHubPageState extends ConsumerState<RollcallHubPage> {
  RollcallHubSegment _segment = RollcallHubSegment.active;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;

    return PageScaffold(
      title: '签到',
      subtitle: _segment == RollcallHubSegment.active
          ? '数字一键签 · 雷达/二维码二级页'
          : '空列表时轮询 · 发现即停 · ≥15s + 抖动',
      showHeader: wide,
      trailing: _segment == RollcallHubSegment.active
          ? const _ActiveRefreshTrailing()
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.pageX,
              0,
              AppSpace.pageX,
              AppSpace.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppSegmentedControl<RollcallHubSegment>(
                value: _segment,
                onChanged: (s) => setState(() => _segment = s),
                segments: const [
                  AppSegment(
                    value: RollcallHubSegment.active,
                    label: '进行中',
                  ),
                  AppSegment(
                    value: RollcallHubSegment.poll,
                    label: '轮询',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _segment == RollcallHubSegment.active
                ? const RollcallListPage(embedded: true)
                : const MonitorPage(embedded: true),
          ),
        ],
      ),
    );
  }
}

/// Manual refresh, or countdown to next poll when monitoring is running.
class _ActiveRefreshTrailing extends ConsumerStatefulWidget {
  const _ActiveRefreshTrailing();

  @override
  ConsumerState<_ActiveRefreshTrailing> createState() =>
      _ActiveRefreshTrailingState();
}

class _ActiveRefreshTrailingState
    extends ConsumerState<_ActiveRefreshTrailing> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final m = ref.read(monitorControllerProvider);
      if (m.running) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _refresh() =>
      ref.read(activeRollcallsProvider.notifier).refresh();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final monitor = ref.watch(monitorControllerProvider);
    final next = monitor.nextPollAt;

    if (!monitor.running || next == null) {
      return IconButton(
        tooltip: '刷新',
        onPressed: _refresh,
        icon: Icon(Icons.refresh_rounded, color: p.muted),
      );
    }

    final secs = next.difference(DateTime.now()).inSeconds;
    final remain = secs < 0 ? 0 : secs;
    final label = '${remain}s';

    return Tooltip(
      message: '下次轮询 ${remain}s · 点击立即刷新',
      child: TextButton(
        onPressed: _refresh,
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
