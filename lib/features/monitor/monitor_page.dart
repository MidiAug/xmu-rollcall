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

    final ready = signedIn && !state.loadingSettings;
    final jitterSeconds = (c.effectiveIntervalSeconds * c.jitterRatio).round();
    final shortest = (c.effectiveIntervalSeconds - jitterSeconds).clamp(
      15,
      180,
    );
    final longest = c.effectiveIntervalSeconds + jitterSeconds;
    return SubpageScaffold(
      title: '签到设置',
      body: AppContentColumn(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpace.pageXOf(context),
            12,
            AppSpace.pageXOf(context),
            24,
          ),
          children: [
            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '自动签到',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              !c.autoAnswer
                                  ? '仅提醒你处理签到，不会自动提交'
                                  : state.running
                                  ? '检测到签到后，按下方规则自动提交'
                                  : '已开启，开始检测后生效',
                              style: TextStyle(fontSize: 12, color: p.muted),
                            ),
                          ],
                        ),
                      ),
                      AppSwitch(
                        value: c.autoAnswer,
                        onChanged: ready ? ctrl.setAutomaticAnswer : null,
                      ),
                    ],
                  ),
                  if (c.autoAnswer) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (final mode in AnswerWaitMode.values) ...[
                          if (mode != AnswerWaitMode.none)
                            const SizedBox(width: 6),
                          Expanded(
                            child: _PresetPill(
                              label: switch (mode) {
                                AnswerWaitMode.none => '直接提交',
                                AnswerWaitMode.count => '等人数',
                                AnswerWaitMode.percent => '等比例',
                              },
                              selected: c.answerWaitMode == mode,
                              onTap: ready
                                  ? () => ctrl.setAnswerWaitMode(mode)
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (c.answerWaitMode != AnswerWaitMode.none) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '已签到门槛',
                              style: TextStyle(fontSize: 13, color: p.muted),
                            ),
                          ),
                          _NumberControl(
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
                            onChanged: (v) {
                              ctrl.setAnswerWaitValue(v);
                              ctrl.commitPersist();
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      c.answerWaitMode == AnswerWaitMode.none
                          ? '确认活动仍在进行、获取有效数字码后提交。'
                          : '按人数轮询间隔核对门槛；最多等待 5 分钟，超时重新检查。',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: p.muted,
                      ),
                    ),
                  ],
                  if (c.autoAnswer) ...[
                    const SizedBox(height: 10),
                    Text(
                      '雷达使用本课已保存的位置；没有位置或提交失败时由你处理。二维码需手动扫码。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '人数轮询间隔',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                          ),
                        ),
                      ),
                      _NumberControl(
                        value: c.effectiveAttendanceIntervalSeconds,
                        unit: '秒',
                        min: 15,
                        max: 120,
                        step: 5,
                        onChanged: ready
                            ? ctrl.setAttendanceIntervalSeconds
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '签到卡片的已签到人数与自动签到等待人数共用此间隔。',
                    style: TextStyle(fontSize: 11, height: 1.5, color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '检测频率',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (final preset in MonitorPreset.values) ...[
                        if (preset != MonitorPreset.classroom)
                          const SizedBox(width: 6),
                        Expanded(
                          child: _PresetPill(
                            label: switch (preset) {
                              MonitorPreset.classroom => '课堂  20秒',
                              MonitorPreset.eco => '省电  60秒',
                              MonitorPreset.custom => '自定义',
                            },
                            selected: c.preset == preset,
                            onTap: ready ? () => ctrl.setPreset(preset) : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (c.preset == MonitorPreset.custom) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '查询间隔',
                            style: TextStyle(fontSize: 13, color: p.muted),
                          ),
                        ),
                        _NumberControl(
                          value: c.effectiveIntervalSeconds,
                          unit: '秒',
                          min: 15,
                          max: 120,
                          step: 5,
                          onChanged: (v) {
                            ctrl.setIntervalSeconds(v);
                            ctrl.commitPersist();
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '随机波动',
                          style: TextStyle(fontSize: 13, color: p.muted),
                        ),
                      ),
                      Text(
                        '±${(c.jitterRatio * 100).round()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      overlayShape: SliderComponentShape.noOverlay,
                      trackHeight: 3,
                    ),
                    child: Slider(
                      key: const ValueKey('monitor-jitter'),
                      min: 0,
                      max: 0.5,
                      divisions: 10,
                      value: c.jitterRatio,
                      label: '±${(c.jitterRatio * 100).round()}%',
                      onChanged: ready ? ctrl.setJitterRatio : null,
                      onChangeEnd: ready ? (_) => ctrl.commitPersist() : null,
                    ),
                  ),
                  Text(
                    shortest == longest
                        ? '正常检测每 $shortest 秒一次；失败时自动退避。'
                        : '正常检测约 $shortest–$longest 秒一次，最短 15 秒；失败时自动退避。',
                    style: TextStyle(fontSize: 11, height: 1.5, color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '最近运行',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    state.logs.isEmpty
                        ? '开始检测后，将显示当前账号的运行结果。'
                        : state.logs.first.message,
                    style: TextStyle(fontSize: 12, height: 1.5, color: p.muted),
                  ),
                  if (state.lastPollAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '上次检查 ${_fmt(state.lastPollAt)}',
                      style: TextStyle(fontSize: 11, color: p.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (PlatformHooks.isAndroid || PlatformHooks.isDesktop)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () => AppPageRoutes.push(
                    context,
                    PlatformHooks.isAndroid
                        ? const NotificationSettingsPage()
                        : const DesktopNotificationSettingsPage(),
                  ),
                  icon: const Icon(Icons.notifications_none_rounded, size: 18),
                  label: const Text('检测提醒与后台运行'),
                ),
              ),
          ],
        ),
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
  final VoidCallback? onTap;

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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }
}

class _NumberControl extends StatelessWidget {
  const _NumberControl({
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });
  final int value, min, max, step;
  final String unit;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.content,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '减少$unit',
            onPressed: value > min && onChanged != null
                ? () => onChanged!((value - step).clamp(min, max))
                : null,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded, size: 17),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$value$unit',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
          ),
          IconButton(
            tooltip: '增加$unit',
            onPressed: value < max && onChanged != null
                ? () => onChanged!((value + step).clamp(min, max))
                : null,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}
