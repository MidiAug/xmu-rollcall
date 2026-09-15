import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';

class MonitorPage extends ConsumerWidget {
  const MonitorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(monitorControllerProvider);
    final ctrl = ref.read(monitorControllerProvider.notifier);
    final c = state.config;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '前台轮询',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Switch(
                      value: state.running,
                      onChanged: (v) => v ? ctrl.start() : ctrl.stop(),
                    ),
                  ],
                ),
                Text(
                  state.running ? '运行中' : '已停止',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '上次：${state.lastPollAt?.toLocal().toString().substring(0, 19) ?? "—"}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '下次：${state.nextPollAt?.toLocal().toString().substring(0, 19) ?? "—"}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('预设', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final p in MonitorPreset.values)
              ChoiceChip(
                label: Text(p.label),
                selected: c.preset == p,
                onSelected: (_) => ctrl.setPreset(p),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          '间隔 ${c.effectiveIntervalSeconds} 秒（最短 ${MonitorConfig.minIntervalSeconds}s）',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          min: MonitorConfig.minIntervalSeconds.toDouble(),
          max: 120,
          divisions: 105,
          value: c.effectiveIntervalSeconds.toDouble().clamp(
                MonitorConfig.minIntervalSeconds.toDouble(),
                120,
              ),
          label: '${c.effectiveIntervalSeconds}s',
          onChanged: (v) => ctrl.setIntervalSeconds(v.round()),
        ),
        Text(
          '抖动 ${(c.jitterRatio * 100).round()}%',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          min: 0,
          max: 0.5,
          divisions: 10,
          value: c.jitterRatio,
          label: '${(c.jitterRatio * 100).round()}%',
          onChanged: ctrl.setJitterRatio,
        ),
        const SizedBox(height: 8),
        Text(
          '默认远慢于 1Hz，失败会拉长间隔。自动应答默认关闭，与监控解耦。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('自动应答（风险）'),
          subtitle: const Text('MVP 强制关闭；提交须本人确认'),
          value: false,
          onChanged: null,
        ),
        const Divider(height: 32),
        Text('最近轮询', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (state.logs.isEmpty)
          Text('暂无日志', style: Theme.of(context).textTheme.bodySmall)
        else
          ...state.logs.take(12).map((e) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                e.ok ? Icons.check_circle_outline : Icons.error_outline,
                color: e.ok ? AppColors.primary : AppColors.danger,
                size: 20,
              ),
              title: Text(e.message, style: Theme.of(context).textTheme.bodySmall),
              subtitle: Text(
                e.at.toLocal().toString().substring(0, 19),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            );
          }),
      ],
    );
  }
}
