/// Discovery bounds for one selected account; interval operations are pure.
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
}

class DetectionWindowClosed implements Exception {
  const DetectionWindowClosed(this.window, this.at);
  final DetectionWindow window;
  final DateTime at;
  @override
  String toString() => '当前不在检测时段（${window.label}），暂不获取签到';
}
