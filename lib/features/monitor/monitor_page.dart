import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_switch.dart';
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
    final p = AppPalette.of(context);
    final state = ref.watch(monitorControllerProvider);
    final ctrl = ref.read(monitorControllerProvider.notifier);
    final c = state.config;
    final signedIn = ref.watch(authControllerProvider).isSignedIn;

    return SubpageScaffold(
      title: '自动检测',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpace.pageXOf(context),
          AppSpace.md,
          AppSpace.pageXOf(context),
          AppSpace.xl,
        ),
        children: [
          SettingsSection(
            header: '状态',
            children: [
              SettingsRow(
                leading: Icon(
                  state.running ? Icons.radar : Icons.radar_outlined,
                  color: state.running ? p.primary : p.muted,
                ),
                title: '自动检测签到',
                subtitle: !signedIn
                    ? '请先登录'
                    : (state.running ? '运行中' : '已停止'),
                trailing: AppSwitch(
                  value: state.running,
                  onChanged: !signedIn
                      ? null
                      : (v) => v ? ctrl.start() : ctrl.stop(),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpace.stackOf(context)),
          SettingsSection(
            header: '最近检测',
            children: [
              _KvRow(label: '上次检测', value: _fmt(state.lastPollAt)),
              _KvRow(label: '下次预计', value: _fmt(state.nextPollAt)),
            ],
          ),
          SizedBox(height: AppSpace.stackOf(context)),
          SettingsSection(
            header: '间隔设置',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.md,
                  AppSpace.md,
                  AppSpace.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '预设',
                      style: TextStyle(fontSize: 12, color: p.muted),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Row(
                      children: [
                        for (var i = 0; i < MonitorPreset.values.length; i++) ...[
                          if (i > 0) const SizedBox(width: AppSpace.xs),
                          Expanded(
                            child: _PresetPill(
                              label: MonitorPreset.values[i].label,
                              selected: c.preset == MonitorPreset.values[i],
                              onTap: () =>
                                  ctrl.setPreset(MonitorPreset.values[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                    _SliderLabel(
                      label: '间隔',
                      value: '${c.effectiveIntervalSeconds} 秒',
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        overlayShape: SliderComponentShape.noOverlay,
                        trackHeight: 3,
                      ),
                      child: Slider(
                        min: MonitorConfig.minIntervalSeconds.toDouble(),
                        max: 120,
                        divisions: 105,
                        value: c.effectiveIntervalSeconds.toDouble().clamp(
                              MonitorConfig.minIntervalSeconds.toDouble(),
                              120,
                            ),
                        onChanged: (v) => ctrl.setIntervalSeconds(v.round()),
                        onChangeEnd: (_) => ctrl.commitPersist(),
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    _SliderLabel(
                      label: '随机波动',
                      value: '${(c.jitterRatio * 100).round()}%',
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        overlayShape: SliderComponentShape.noOverlay,
                        trackHeight: 3,
                      ),
                      child: Slider(
                        min: 0,
                        max: 0.5,
                        divisions: 10,
                        value: c.jitterRatio,
                        onChanged: ctrl.setJitterRatio,
                        onChangeEnd: (_) => ctrl.commitPersist(),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    Text(
                      '实际间隔会在设定值附近小幅变化，最短 15 秒。',
                      style: TextStyle(fontSize: 12, height: 1.4, color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpace.stackOf(context)),
          SettingsSection(
            header: '最近记录',
            children: [
              if (state.logs.isEmpty)
                Padding(
                  padding: AppDensity.rowPadding(context),
                  child: Text(
                    '尚无检测记录',
                    style: TextStyle(fontSize: 13, color: p.muted),
                  ),
                )
              else
                for (final e in state.logs.take(12)) _LogRow(entry: e),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime? t) {
    if (t == null) return '—';
    return t.toLocal().toString().substring(0, 19);
  }
}

class _PresetPill extends StatelessWidget {
  const _PresetPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.duration,
        curve: AppMotion.curve,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? p.selected : p.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? p.primary : p.muted,
          ),
        ),
      ),
    );
  }
}

class _SliderLabel extends StatelessWidget {
  const _SliderLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: p.ink)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: p.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: AppDensity.rowPadding(context),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: p.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: p.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final PollLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: AppDensity.rowPadding(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              entry.ok ? Icons.check_circle_outline : Icons.error_outline,
              size: 18,
              color: entry.ok ? p.primary : p.danger,
            ),
          ),
          SizedBox(width: AppDensity.rowInnerGap(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.message,
                  style: TextStyle(fontSize: 13, height: 1.35, color: p.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.at.toLocal().toString().substring(0, 19),
                  style: TextStyle(
                    fontSize: 11,
                    color: p.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
