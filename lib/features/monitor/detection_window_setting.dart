import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_switch.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';

class DetectionWindowSetting extends ConsumerStatefulWidget {
  const DetectionWindowSetting({
    super.key,
    required this.enabled,
    required this.padding,
  });
  final bool enabled;
  final EdgeInsets padding;
  @override
  ConsumerState<DetectionWindowSetting> createState() =>
      _DetectionWindowSettingState();
}

class _DetectionWindowSettingState
    extends ConsumerState<DetectionWindowSetting> {
  bool _saving = false;
  String? _error;
  Future<void> _save(DetectionWindow window) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(detectionWindowProvider.notifier).save(window);
    } catch (_) {
      if (mounted) setState(() => _error = '时段未能保存，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pick(DetectionWindow window, bool start) async {
    final minute = start ? window.startMinute : window.endMinute;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: start ? '开始时间' : '结束时间',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || time == null) return;
    final next = time.hour * 60 + time.minute;
    if (next == (start ? window.endMinute : window.startMinute)) {
      setState(() => _error = '开始和结束时间不能相同');
      return;
    }
    await _save(
      DetectionWindow(
        enabled: window.enabled,
        startMinute: start ? next : window.startMinute,
        endMinute: start ? window.endMinute : next,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final window = ref.watch(detectionWindowProvider);
    final enabled = widget.enabled && window != null && !_saving;
    return Column(
      children: [
        SettingsRow(
          contentPadding: widget.padding,
          subtitleSpacing: 6,
          minHeight: 40,
          title: '检测时段',
          subtitle: _error ?? '时段外暂停获取签到，手动刷新也适用',
          stackSubtitleOnNarrow: true,
          trailing: SizedBox(
            width: 148,
            child: Align(
              alignment: Alignment.centerRight,
              child: AppSwitch(
                key: const ValueKey('detection-window-switch'),
                value: window?.enabled ?? false,
                onChanged: enabled
                    ? (value) => _save(
                        DetectionWindow(
                          enabled: value,
                          startMinute: window.startMinute,
                          endMinute: window.endMinute,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        if (window?.enabled == true) ...[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.padding.horizontal / 2,
            ),
            child: const Divider(height: 1),
          ),
          SettingsRow(
            contentPadding: widget.padding,
            minHeight: 40,
            title: '生效时间',
            subtitle: window!.startMinute > window.endMinute
                ? '结束时间为次日'
                : '每天生效',
            stackSubtitleOnNarrow: true,
            trailing: SizedBox(
              width: 148,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: enabled ? () => _pick(window, true) : null,
                      child: Text(
                        DetectionWindow.formatMinute(window.startMinute),
                      ),
                    ),
                  ),
                  const Text('–'),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: enabled ? () => _pick(window, false) : null,
                      child: Text(
                        DetectionWindow.formatMinute(window.endMinute),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
