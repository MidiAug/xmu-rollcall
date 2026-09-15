import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';

class MonitorPage extends ConsumerWidget {
  const MonitorPage({super.key, this.embedded = false});

  /// When true, omit outer [PageScaffold] (used inside rollcall hub).
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final state = ref.watch(monitorControllerProvider);
    final ctrl = ref.read(monitorControllerProvider.notifier);
    final c = state.config;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.pageX,
        AppSpace.xxs,
        AppSpace.pageX,
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
                      '\u8f6e\u8be2\u5f00\u5173',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.running
                          ? '\u8fd0\u884c\u4e2d'
                          : '\u5df2\u505c\u6b62',
                      style: TextStyle(
                        fontSize: 12,
                        color: state.running ? palette.primary : palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: state.running,
                onChanged: (v) => v ? ctrl.start() : ctrl.stop(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.stack),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_outlined, size: 16, color: palette.muted),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    '\u65f6\u95f4\u7ebf',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: palette.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              _MetaRow(label: '\u4e0a\u6b21\u8f6e\u8be2', value: _fmt(state.lastPollAt)),
              const SizedBox(height: AppSpace.xs),
              _MetaRow(label: '\u4e0b\u6b21\u9884\u8ba1', value: _fmt(state.nextPollAt)),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.stack),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_outlined, size: 16, color: palette.muted),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    '\u53c2\u6570',
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
                '\u95f4\u9694 ${c.effectiveIntervalSeconds} \u79d2',
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
                '\u6296\u52a8 ${(c.jitterRatio * 100).round()}%',
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
                '\u5b9e\u9645\u95f4\u9694 = \u57fa\u51c6 \u00b1 \u6296\u52a8\uff0c\u4e14\u4ece\u4e0d\u4f4e\u4e8e 15 \u79d2\uff08\u5bf9\u9f50 KB-01\uff09\u3002',
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.stack),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.list_alt_outlined, size: 16, color: palette.muted),
                  const SizedBox(width: AppSpace.xs),
                  Text(
                    '\u6700\u8fd1\u65e5\u5fd7',
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
                  '\u5c1a\u65e0\u8f6e\u8be2\u8bb0\u5f55',
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
    );

    if (embedded) return body;
    return PageScaffold(
      title: '\u8f6e\u8be2',
      subtitle: '\u53ef\u914d\u7f6e\u8f6e\u8be2 \u00b7 \u4e0d\u4f4e\u4e8e 15s + \u6296\u52a8',
      showHeader: wide,
      child: body,
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
