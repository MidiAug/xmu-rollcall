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
      MonitorConfig.minIntervalSeconds,
      MonitorConfig.maxIntervalSeconds,
    );
    final longest = c.effectiveIntervalSeconds + jitterSeconds;
    final intervalDescription = shortest == longest
        ? '每 $shortest 秒检查一次'
        : '约 $shortest–$longest 秒检查一次';
    final rowPadding = EdgeInsets.symmetric(
      horizontal: AppDensity.isTouch(context) ? 12 : 20,
      vertical: 12,
    );
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.copyWith(
          titleMedium: theme.textTheme.titleMedium?.copyWith(height: 1.4),
          titleSmall: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          bodyMedium: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          bodySmall: theme.textTheme.bodySmall?.copyWith(
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
      child: Builder(
        builder: (context) {
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
                    header: '签到规则',
                    hasLeading: false,
                    rowPadding: rowPadding,
                    footer: c.autoAnswer
                        ? Text(
                            '雷达使用本课已保存的位置；缺少位置或失败时请手动处理。二维码需扫码。',
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        : null,
                    children: [
                      SettingsRow(
                        contentPadding: rowPadding,
                        subtitleSpacing: 6,
                        minHeight: 40,
                        title: '自动签到',
                        stackSubtitleOnNarrow: true,
                        subtitle: !c.autoAnswer
                            ? '仅提醒，不会自动提交'
                            : state.running
                            ? '发现签到后，按规则自动提交'
                            : '已开启，开始检测后生效',
                        trailing: SizedBox(
                          width: 148,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: AppSwitch(
                              value: c.autoAnswer,
                              onChanged: ready ? ctrl.setAutomaticAnswer : null,
                            ),
                          ),
                        ),
                      ),
                      if (c.autoAnswer) ...[
                        SettingsRow(
                          contentPadding: rowPadding,
                          minHeight: 40,
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
                            contentPadding: rowPadding,
                            subtitleSpacing: 6,
                            minHeight: 40,
                            title: c.answerWaitMode == AnswerWaitMode.count
                                ? '已签到人数'
                                : '已签到比例',
                            stackSubtitleOnNarrow: true,
                            subtitle: '达到后提交，最多等待 5 分钟',
                            trailing: _NumberControl(
                              key: const ValueKey('monitor-answer-control'),
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
                      ],
                    ],
                  ),
                  SettingsSection(
                    header: '检测与提醒',
                    hasLeading: false,
                    rowPadding: rowPadding,
                    children: [
                      _SliderSetting(
                        padding: rowPadding,
                        title: '检测间隔',
                        sliderKey: const ValueKey('monitor-interval'),
                        value: c.effectiveIntervalSeconds.toDouble(),
                        valueLabel: '${c.effectiveIntervalSeconds} 秒',
                        min: MonitorConfig.minIntervalSeconds.toDouble(),
                        max: MonitorConfig.maxIntervalSeconds.toDouble(),
                        divisions:
                            (MonitorConfig.maxIntervalSeconds -
                                MonitorConfig.minIntervalSeconds) ~/
                            MonitorConfig.intervalStepSeconds,
                        formatValue: (value) => '${value.round()} 秒',
                        onChanged: ready
                            ? (value) => ctrl.setIntervalSeconds(value.round())
                            : null,
                        onChangeEnd: ready ? (_) => ctrl.commitPersist() : null,
                      ),
                      _SliderSetting(
                        padding: rowPadding,
                        title: '随机扰动',
                        sliderKey: const ValueKey('monitor-jitter'),
                        value: c.jitterRatio,
                        valueLabel: '±${(c.jitterRatio * 100).round()}%',
                        min: 0,
                        max: 0.5,
                        divisions: 10,
                        formatValue: (value) =>
                            '上下浮动百分之${(value * 100).round()}',
                        onChanged: ready ? ctrl.setJitterRatio : null,
                        onChangeEnd: ready ? (_) => ctrl.commitPersist() : null,
                        description: '$intervalDescription；连接失败时会延后重试。',
                      ),
                      SettingsRow(
                        contentPadding: rowPadding,
                        subtitleSpacing: 6,
                        minHeight: 40,
                        title: '人数刷新',
                        stackSubtitleOnNarrow: true,
                        subtitle: '卡片与自动签到共用刷新间隔',
                        trailing: _NumberControl(
                          key: const ValueKey('monitor-attendance-control'),
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
                      if (PlatformHooks.isAndroid || PlatformHooks.isDesktop)
                        SettingsRow(
                          contentPadding: rowPadding,
                          minHeight: 40,
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
                      if (state.logs.isNotEmpty) ...[
                        SettingsRow(
                          contentPadding: rowPadding,
                          subtitleSpacing: 6,
                          minHeight: 40,
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    log.message,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: log.ok ? p.ink : p.danger,
                                        ),
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
        },
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
    super.key,
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
    final valueLabel = unit == '%' ? '$value%' : '$value $unit';
    Widget button({required bool increase}) => SizedBox.square(
      dimension: target,
      child: IconButton(
        tooltip: '${increase ? '增加' : '减少'}$label',
        onPressed: onChanged != null && (increase ? value < max : value > min)
            ? () => onChanged!(
                (value + (increase ? step : -step)).clamp(min, max),
              )
            : null,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(
          increase ? Icons.add_rounded : Icons.remove_rounded,
          size: 17,
        ),
      ),
    );
    return Semantics(
      label: label,
      value: valueLabel,
      child: SizedBox(
        width: 148,
        height: target,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.content,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              button(increase: false),
              Expanded(
                child: Text(
                  valueLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              button(increase: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.padding,
    required this.title,
    required this.sliderKey,
    required this.value,
    required this.valueLabel,
    required this.min,
    required this.max,
    required this.divisions,
    required this.formatValue,
    required this.onChanged,
    required this.onChangeEnd,
    this.description,
  });

  final String title, valueLabel;
  final EdgeInsets padding;
  final String? description;
  final Key sliderKey;
  final double value, min, max;
  final int divisions;
  final String Function(double) formatValue;
  final ValueChanged<double>? onChanged, onChangeEnd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SizedBox(
              width: 148,
              child: Text(
                valueLabel,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: title,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 7,
                disabledThumbRadius: 6,
                elevation: 0,
                pressedElevation: 0,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              overlayColor: AppPalette.of(
                context,
              ).primary.withValues(alpha: 0.12),
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Slider(
              key: sliderKey,
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              semanticFormatterCallback: formatValue,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(description!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );
}
