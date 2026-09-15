import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/monitor/monitor_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';

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
          ? '进行中课堂 · 数字 / 雷达应答'
          : '可配置轮询 · 不低于 15s + 抖动',
      showHeader: wide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
