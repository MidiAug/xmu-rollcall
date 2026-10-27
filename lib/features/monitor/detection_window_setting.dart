import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_switch.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/schedule_detection.dart';

final selectedDetectionWindowProvider =
    FutureProvider.autoDispose<DetectionWindow>((ref) async {
      ref.watch(detectionWindowProvider);
      ref.watch(academicRevisionProvider);
      final uid =
          ref.watch(selectedRollcallAccountProvider) ??
          ref.watch(authControllerProvider).profile?.id;
      return readScheduleDetectionWindow(
        uid,
        at: ref.read(activeRollcallClockProvider)(),
      );
    });

String todayDetectionRanges(DetectionWindow window, DateTime now) {
  if (!window.enabled) return '全天可自动检测';
  final day = DateTime(now.year, now.month, now.day);
  final end = DateTime(now.year, now.month, now.day + 1);
  String hm(DateTime time) =>
      DetectionWindow.formatMinute(time.hour * 60 + time.minute);
  final ranges = [
    for (final range
        in window.intervals ?? <({DateTime start, DateTime end})>[])
      if (range.end.isAfter(day) && range.start.isBefore(end))
        '${range.start.isBefore(day) ? '00:00' : hm(range.start)}—${!range.end.isBefore(end) ? '24:00' : hm(range.end)}',
  ];
  return ranges.isEmpty ? '今日无可推算的检测范围' : ranges.join('、');
}

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
  Future<void> _save(bool enabled) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(detectionWindowProvider.notifier)
          .save(DetectionWindow(scheduleBased: true, enabled: enabled));
    } catch (_) {
      if (mounted) setState(() => _error = '检测范围未能保存，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setting = ref.watch(detectionWindowProvider);
    final planned = ref.watch(selectedDetectionWindowProvider);
    final now = ref.read(activeRollcallClockProvider)();
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          contentPadding: widget.padding,
          subtitleSpacing: 6,
          title: '按课表检测',
          subtitle: _error ?? '仅在课前30分钟至课后30分钟自动检测，手动检测不受限',
          stackSubtitleOnNarrow: true,
          trailing: AppSwitch(
            key: const ValueKey('detection-window-switch'),
            value: setting?.enabled ?? true,
            onChanged: widget.enabled && setting != null && !_saving
                ? _save
                : null,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.padding.left,
            0,
            widget.padding.right,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '今日检测范围',
                style: AppTypography.control.copyWith(color: p.ink),
              ),
              const SizedBox(height: 6),
              Text(
                planned.when(
                  data: (window) => todayDetectionRanges(window, now),
                  loading: () => '正在读取课表…',
                  error: (_, _) => '暂时无法读取课表，可手动检测',
                ),
                style: AppTypography.caption.copyWith(color: p.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
