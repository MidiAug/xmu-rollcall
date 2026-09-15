import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
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
    final p = AppPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;

    return PageScaffold(
      title: '签到',
      subtitle: _segment == RollcallHubSegment.active
          ? '数字一键签 · 雷达/二维码二级页'
          : '空列表时轮询 · 发现即停 · ≥15s + 抖动',
      showHeader: wide,
      trailing: _segment == RollcallHubSegment.active
          ? IconButton(
              tooltip: '刷新',
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  ref.read(activeRollcallsProvider.notifier).refresh(),
              icon: Icon(Icons.refresh_rounded, color: p.muted),
            )
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
            child: SegmentedButton<RollcallHubSegment>(
              segments: const [
                ButtonSegment(
                  value: RollcallHubSegment.active,
                  icon: Icon(Icons.list_alt_outlined, size: 16),
                  label: Text('进行中'),
                ),
                ButtonSegment(
                  value: RollcallHubSegment.poll,
                  icon: Icon(Icons.radar_outlined, size: 16),
                  label: Text('轮询'),
                ),
              ],
              selected: {_segment},
              onSelectionChanged: (s) => setState(() => _segment = s.first),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) return p.ink;
                  return p.muted;
                }),
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
