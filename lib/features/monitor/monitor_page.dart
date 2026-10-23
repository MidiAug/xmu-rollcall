import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_switch.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/settings/notification_settings_page.dart';
import 'package:xmu_rollcall/features/settings/desktop_notification_settings_page.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

class MonitorSettingsPage extends ConsumerStatefulWidget {
  const MonitorSettingsPage({super.key});

  @override
  ConsumerState<MonitorSettingsPage> createState() =>
      _MonitorSettingsPageState();
}

class _MonitorSettingsPageState extends ConsumerState<MonitorSettingsPage> {
  bool _showMore = false;
  bool _showLogs = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final state = ref.watch(monitorControllerProvider);
    final ctrl = ref.read(monitorControllerProvider.notifier);
    final c = state.config;
    final ready =
        ref.watch(authControllerProvider).isSignedIn && !state.loadingSettings;
    final jitterSeconds = (c.effectiveIntervalSeconds * c.jitterRatio).round();
    final shortest = (c.effectiveIntervalSeconds - jitterSeconds).clamp(
      15,
      180,
    );
    final longest = c.effectiveIntervalSeconds + jitterSeconds;
    final intervalDescription = shortest == longest
        ? '每 $shortest 秒检查一次'
        : '约 $shortest–$longest 秒检查一次';
    final rowPadding = AppDensity.rowPadding(context);

    return SubpageScaffold(
      title: '签到设置',
      body: AppContentColumn(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpace.pageXOf(context),
            AppSpace.md,
            AppSpace.pageXOf(context),
            AppSpace.xl,
          ),
          children: [
            SettingsSection(
              padTop: false,
              hasLeading: false,
              children: [
                SettingsRow(
                  title: '自动签到',
                  stackSubtitleOnNarrow: true,
                  subtitle: !c.autoAnswer
                      ? '仅提醒你处理签到，不会自动提交'
                      : state.running
                      ? '检测到签到后，按下方规则自动提交'
                      : '已开启，开始检测后生效',
                  trailing: AppSwitch(
                    value: c.autoAnswer,
                    onChanged: ready ? ctrl.setAutomaticAnswer : null,
                  ),
                ),
                if (c.autoAnswer) ...[
                  SettingsRow(
                    title: '提交时机',
                    trailing: AppShellSelect<AnswerWaitMode>(
                      semanticLabel: '提交时机',
                      value: c.answerWaitMode,
                      items: AnswerWaitMode.values,
                      labelOf: (mode) => switch (mode) {
                        AnswerWaitMode.none => '直接提交',
                        AnswerWaitMode.count => '等待人数',
                        AnswerWaitMode.percent => '等待比例',
                      },
                      width: 148,
                      onChanged: ready ? ctrl.setAnswerWaitMode : null,
                    ),
                  ),
                  if (c.answerWaitMode != AnswerWaitMode.none)
                    SettingsRow(
                      title: c.answerWaitMode == AnswerWaitMode.count
                          ? '已签到人数'
                          : '已签到比例',
                      stackSubtitleOnNarrow: true,
                      subtitle: '达到后提交，最多等待 5 分钟',
                      trailing: _NumberControl(
                        label: c.answerWaitMode == AnswerWaitMode.count
                            ? '已签到人数'
                            : '已签到比例',
                        value: c.answerWaitMode == AnswerWaitMode.count
                            ? c.answerWaitCount
                            : c.answerWaitPercent,
                        unit: c.answerWaitMode == AnswerWaitMode.count
                            ? '人'
                            : '%',
                        min: 1,
                        max: c.answerWaitMode == AnswerWaitMode.count
                            ? 200
                            : 100,
                        onChanged: ready
                            ? (value) {
                                ctrl.setAnswerWaitValue(value);
                                ctrl.commitPersist();
                              }
                            : null,
                      ),
                    ),
                  Padding(
                    padding: rowPadding,
                    child: Text(
                      '雷达使用本课已保存的位置；没有位置或提交失败时由你处理。二维码需手动扫码。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                SettingsRow(
                  title: '检测间隔',
                  stackSubtitleOnNarrow: true,
                  subtitle: intervalDescription,
                  trailing: AppShellSelect<MonitorPreset>(
                    semanticLabel: '检测间隔',
                    value: c.preset,
                    items: MonitorPreset.values,
                    labelOf: (preset) => switch (preset) {
                      MonitorPreset.classroom => '课堂 · 20 秒',
                      MonitorPreset.eco => '省电 · 60 秒',
                      MonitorPreset.custom => '自定义',
                    },
                    width: 148,
                    onChanged: ready ? ctrl.setPreset : null,
                  ),
                ),
                if (c.preset == MonitorPreset.custom)
                  SettingsRow(
                    title: '自定义间隔',
                    trailing: _NumberControl(
                      label: '检测间隔',
                      value: c.effectiveIntervalSeconds,
                      unit: '秒',
                      min: 15,
                      max: 120,
                      step: 5,
                      onChanged: ready
                          ? (value) {
                              ctrl.setIntervalSeconds(value);
                              ctrl.commitPersist();
                            }
                          : null,
                    ),
                  ),
                if (PlatformHooks.isAndroid || PlatformHooks.isDesktop)
                  SettingsRow(
                    title: '提醒与后台运行',
                    trailing: Icon(
                      Icons.chevron_right,
                      color: p.muted,
                      size: 18,
                    ),
                    onTap: () => AppPageRoutes.push(
                      context,
                      PlatformHooks.isAndroid
                          ? const NotificationSettingsPage()
                          : const DesktopNotificationSettingsPage(),
                    ),
                  ),
              ],
            ),
            SettingsSection(
              hasLeading: false,
              children: [
                SettingsRow(
                  key: const ValueKey('monitor-more'),
                  title: '更多设置',
                  subtitle: _showMore ? null : '人数刷新、间隔浮动',
                  trailing: _DisclosureIcon(expanded: _showMore),
                  onTap: () => setState(() => _showMore = !_showMore),
                ),
                if (_showMore) ...[
                  SettingsRow(
                    title: '人数刷新',
                    stackSubtitleOnNarrow: true,
                    subtitle: '用于签到卡片和自动签到的等待人数',
                    trailing: _NumberControl(
                      label: '人数刷新间隔',
                      value: c.effectiveAttendanceIntervalSeconds,
                      unit: '秒',
                      min: 15,
                      max: 120,
                      step: 5,
                      onChanged: ready
                          ? ctrl.setAttendanceIntervalSeconds
                          : null,
                    ),
                  ),
                  Padding(
                    padding: rowPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '间隔浮动',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              '±${(c.jitterRatio * 100).round()}%',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        Slider(
                          key: const ValueKey('monitor-jitter'),
                          min: 0,
                          max: 0.5,
                          divisions: 10,
                          value: c.jitterRatio,
                          semanticFormatterCallback: (value) =>
                              '上下浮动百分之${(value * 100).round()}',
                          label: '±${(c.jitterRatio * 100).round()}%',
                          onChanged: ready ? ctrl.setJitterRatio : null,
                          onChangeEnd: ready
                              ? (_) => ctrl.commitPersist()
                              : null,
                        ),
                        Text(
                          '$intervalDescription，最短 15 秒。连接失败时会延后重试。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
                if (state.logs.isNotEmpty) ...[
                  SettingsRow(
                    key: const ValueKey('monitor-logs'),
                    title: '最近运行',
                    subtitle: _showLogs ? null : '查看最近的检测记录',
                    trailing: _DisclosureIcon(expanded: _showLogs),
                    onTap: () => setState(() => _showLogs = !_showLogs),
                  ),
                  if (_showLogs)
                    for (final log in state.logs.take(5))
                      Padding(
                        padding: rowPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatTime(log.at),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              log.message,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: log.ok ? p.ink : p.danger),
                            ),
                          ],
                        ),
                      ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.month}月${local.day}日 ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}

class _DisclosureIcon extends StatelessWidget {
  const _DisclosureIcon({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: expanded ? 0.5 : 0,
    duration: AppMotion.fast,
    child: Icon(
      Icons.expand_more_rounded,
      size: 18,
      color: AppPalette.of(context).muted,
    ),
  );
}

class _NumberControl extends StatelessWidget {
  const _NumberControl({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });
  final String label;
  final int value, min, max, step;
  final String unit;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final target = AppDensity.isTouch(context) ? 44.0 : 36.0;
    return Semantics(
      label: label,
      value: '$value$unit',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.content,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '减少$label',
              onPressed: value > min && onChanged != null
                  ? () => onChanged!((value - step).clamp(min, max))
                  : null,
              constraints: BoxConstraints.tightFor(
                width: target,
                height: target,
              ),
              visualDensity: VisualDensity.standard,
              icon: const Icon(Icons.remove_rounded, size: 17),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '$value$unit',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              tooltip: '增加$label',
              onPressed: value < max && onChanged != null
                  ? () => onChanged!((value + step).clamp(min, max))
                  : null,
              constraints: BoxConstraints.tightFor(
                width: target,
                height: target,
              ),
              visualDensity: VisualDensity.standard,
              icon: const Icon(Icons.add_rounded, size: 17),
            ),
          ],
        ),
      ),
    );
  }
}
