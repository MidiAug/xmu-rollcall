import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A device-local daily discovery window, shared by owner and assist sessions.
class DetectionWindow {
  const DetectionWindow({
    this.enabled = false,
    this.startMinute = 450,
    this.endMinute = 1320,
    this.intervals,
    this.scheduleBased = false,
    this.hasSchedule = false,
  });
  final bool enabled;
  final bool scheduleBased;
  final bool hasSchedule;
  static const schedulePreferenceKey = 'schedule_detection_only_v2';
  final int startMinute;
  final int endMinute;

  /// Absolute local course windows, already unioned. Null = no known schedule.
  final List<({DateTime start, DateTime end})>? intervals;
  static const preferencesKey = 'rollcall_detection_window';

  static String formatMinute(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
  String get label => scheduleBased
      ? '课前30分钟至课后30分钟'
      : intervals == null
      ? '${formatMinute(startMinute)}–${formatMinute(endMinute)}'
      : '按课表：课前30分钟至课后30分钟';

  bool allows(DateTime at) {
    if (scheduleBased) {
      return !enabled ||
          intervals == null ||
          intervals!.any((r) => !at.isBefore(r.start) && at.isBefore(r.end));
    }
    if (intervals != null &&
        !intervals!.any((r) => !at.isBefore(r.start) && !at.isAfter(r.end))) {
      return false;
    }
    if (!enabled) return true;
    final local = at.toLocal();
    final minute = local.hour * 60 + local.minute;
    return startMinute < endMinute
        ? minute >= startMinute && minute < endMinute
        : minute >= startMinute || minute < endMinute;
  }

  DateTime nextStart(DateTime at) {
    final local = at.toLocal();
    if (scheduleBased) {
      if (!enabled) return local;
      for (final range in intervals ?? <({DateTime start, DateTime end})>[]) {
        if (!range.end.isAfter(local)) continue;
        return range.start.isAfter(local) ? range.start : local;
      }
      return DateTime(local.year, local.month, local.day + 1);
    }
    if (intervals != null) {
      for (final range in intervals!) {
        if (range.end.isBefore(local)) continue;
        var candidate = range.start.isAfter(local) ? range.start : local;
        if (!enabled || _dailyAllows(candidate)) return candidate;
        candidate = DetectionWindow(
          enabled: true,
          startMinute: startMinute,
          endMinute: endMinute,
        ).nextStart(candidate);
        if (!candidate.isAfter(range.end)) return candidate;
      }
      // Re-evaluate local schedule after the term, without sending a request.
      return local.add(const Duration(days: 1));
    }
    final start = DateTime(
      local.year,
      local.month,
      local.day,
      startMinute ~/ 60,
      startMinute % 60,
    );
    return start.isAfter(local)
        ? start
        : DateTime(
            local.year,
            local.month,
            local.day + 1,
            startMinute ~/ 60,
            startMinute % 60,
          );
  }

  bool _dailyAllows(DateTime at) => DetectionWindow(
    enabled: enabled,
    startMinute: startMinute,
    endMinute: endMinute,
  ).allows(at);

  static Future<DetectionWindow> read({bool reload = false, int? uid}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    // Legacy clock-hour restrictions are retired. Existing schedule gating
    // remains enabled by default; the new switch explicitly controls it.
    return DetectionWindow(
      scheduleBased: true,
      enabled:
          (uid == null
              ? null
              : prefs.getBool('${schedulePreferenceKey}_$uid')) ??
          ((uid == null ||
                  prefs.getInt('schedule_detection_legacy_owner') == null ||
                  prefs.getInt('schedule_detection_legacy_owner') == uid)
              ? prefs.getBool(schedulePreferenceKey)
              : null) ??
          true,
    );
  }
}

class DetectionWindowClosed implements Exception {
  const DetectionWindowClosed(this.window, this.at);
  final DetectionWindow window;
  final DateTime at;
  @override
  String toString() => '当前不在检测时段（${window.label}），暂不获取签到';
}

final detectionWindowProvider =
    StateNotifierProvider<DetectionWindowController, DetectionWindow?>((ref) {
      final owner = ref.watch(authControllerProvider).profile?.id;
      return DetectionWindowController(
        userId: ref.watch(selectedRollcallAccountProvider) ?? owner,
        ownerId: owner,
      );
    });

class DetectionWindowController extends StateNotifier<DetectionWindow?> {
  DetectionWindowController({this.userId, this.ownerId}) : super(null) {
    ready = _load();
  }
  final int? userId, ownerId;
  late final Future<void> ready;
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (ownerId != null &&
        prefs.getInt('schedule_detection_legacy_owner') == null) {
      await prefs.setInt('schedule_detection_legacy_owner', ownerId!);
    }
    final window = await DetectionWindow.read(uid: userId);
    if (mounted) state = window;
  }

  Future<void> save(DetectionWindow window) async {
    if (window.scheduleBased) {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(
        userId == null
            ? DetectionWindow.schedulePreferenceKey
            : '${DetectionWindow.schedulePreferenceKey}_$userId',
        window.enabled,
      )) {
        throw StateError('无法保存检测范围');
      }
      if (mounted) state = window;
      return;
    }
    if (window.startMinute == window.endMinute ||
        window.startMinute < 0 ||
        window.endMinute < 0 ||
        window.startMinute > 1439 ||
        window.endMinute > 1439) {
      throw ArgumentError('无效检测时段');
    }
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
      DetectionWindow.preferencesKey,
      jsonEncode({
        'enabled': window.enabled,
        'start': window.startMinute,
        'end': window.endMinute,
      }),
    );
    if (!ok) throw StateError('无法保存检测时段');
    if (mounted) state = window;
  }
}
