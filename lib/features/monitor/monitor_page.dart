import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';

/// Secondary page: poll interval / jitter / presets / logs.
class MonitorSettingsPage extends ConsumerWidget {
  const MonitorSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final state = ref.watch(monitorControllerProvider);
    final ctrl = ref.read(monitorControllerProvider.notifier);
    final c = state.config;
    final signedIn = ref.watch(authControllerProvider).isSignedIn;

    return SubpageScaffold(
      title: '轮询设置',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpace.pageXOf(context),
          AppSpace.md,
          AppSpace.pageXOf(context),
          AppSpace.xl,
        ),
        children: [
          Panel(
            child: Row(
              children: [
                Icon(
                  state.running ? Icons.radar : Icons.radar_outlined,
                  size: 22,
                  color: state.running ? palette.primary : palette.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '轮询状态',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        !signedIn
                            ? '请先登录'
                            : (state.running ? '运行中' : '已停止'),
                        style: TextStyle(
                          fontSize: 12,
                          color: !signedIn
                              ? palette.muted
                              : (state.running
                                  ? palette.primary
                                  : palette.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: state.running,
                  onChanged: !signedIn
                      ? null
                      : (v) => v ? ctrl.start() : ctrl.stop(),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpace.stackOf(context)),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_outlined, size: 16, color: palette.muted),
                    const SizedBox(width: AppSpace.xs),
                    Text(
                      '时间线',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                _MetaRow(label: '上次轮询', value: _fmt(state.lastPollAt)),
                const SizedBox(height: AppSpace.xs),
                _MetaRow(label: '下次预计', value: _fmt(state.nextPollAt)),
              ],
            ),
          ),
          SizedBox(height: AppSpace.stackOf(context)),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_outlined, size: 16, color: palette.muted),
                    const SizedBox(width: AppSpace.xs),
                    Text(
                      '参数',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.xs,
                  runSpacing: AppSpace.xs,
                  children: [
                    for (final preset in MonitorPreset.values)
                      ChoiceChip(
                        label: Text(preset.label),
                        selected: c.preset == preset,
                        onSelected: (_) => ctrl.setPreset(preset),
                        selectedColor: palette.primary.withValues(alpha: 0.22),
                        labelStyle: TextStyle(
                          color:
                              c.preset == preset ? palette.ink : palette.muted,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: c.preset == preset
                              ? palette.primary.withValues(alpha: 0.45)
                              : palette.border,
                        ),
                        backgroundColor: palette.content,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  '间隔 ${c.effectiveIntervalSeconds} 秒',
                  style: TextStyle(fontSize: 13, color: palette.ink),
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
                  style: TextStyle(fontSize: 13, color: palette.ink),
                ),
                Slider(
                  min: 0,
                  max: 0.5,
                  divisions: 10,
                  value: c.jitterRatio,
                  label: '${(c.jitterRatio * 100).round()}%',
                  onChanged: ctrl.setJitterRatio,
                ),
                Text(
                  '实际间隔 = 基准 ± 抖动，且从不低于 15 秒（对齐 KB-01）。',
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpace.stackOf(context)),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.list_alt_outlined, size: 16, color: palette.muted),
                    const SizedBox(width: AppSpace.xs),
                    Text(
                      '最近日志',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                if (state.logs.isEmpty)
                  Text(
                    '尚无轮询记录',
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  )
                else
                  ...state.logs.take(12).map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            e.ok
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            size: 18,
                            color: e.ok ? palette.primary : palette.danger,
                          ),
                          const SizedBox(width: AppSpace.xs),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.ink,
                                  ),
                                ),
                                Text(
                                  e.at.toLocal().toString().substring(0, 19),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime? t) {
    if (t == null) return '-';
    return t.toLocal().toString().substring(0, 19);
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: palette.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12, color: palette.ink),
          ),
        ),
      ],
    );
  }
}
