import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Formats remaining time until [nextPollAt] for the ongoing notification body.
String formatMonitorCountdown(DateTime? nextPollAt, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  if (nextPollAt == null) return '即将检测';
  final secs = nextPollAt.difference(clock).inSeconds;
  if (secs <= 0) return '即将检测';
  final m = secs ~/ 60;
  final s = secs % 60;
  if (m <= 0) return '下次检测约 ${s}s';
  return '下次检测约 $m:${s.toString().padLeft(2, '0')}';
}

/// Entry-point for the Android FGS isolate (must stay top-level).
@pragma('vm:entry-point')
void androidMonitorTaskCallback() {
  FlutterForegroundTask.setTaskHandler(AndroidMonitorTaskHandler());
}

class AndroidMonitorTaskHandler extends TaskHandler {
  DateTime? _nextPollAt;

  static const _kNextPollAtMs = 'nextPollAtMs';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final ms = await FlutterForegroundTask.getData<int>(key: _kNextPollAtMs);
    if (ms != null) {
      _nextPollAt = DateTime.fromMillisecondsSinceEpoch(ms);
    }
    _refreshNotification();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _refreshNotification();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (isTimeout) {
      FlutterForegroundTask.sendDataToMain(const {'action': 'timeout'});
    }
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final ms = data[_kNextPollAtMs];
      if (ms is int) {
        _nextPollAt = DateTime.fromMillisecondsSinceEpoch(ms);
        _refreshNotification();
      }
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {
    FlutterForegroundTask.sendDataToMain(const {'action': 'dismissed'});
  }

  void _refreshNotification() {
    FlutterForegroundTask.updateService(
      notificationTitle: '厦大签到检测中',
      notificationText: formatMonitorCountdown(_nextPollAt),
    );
  }
}
