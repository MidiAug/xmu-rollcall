import 'package:xmu_rollcall/app/app_brand.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';

/// Only visible task phases participate, excluding logs and countdown ticks.
({bool active, String tooltip}) desktopTrayStatus(MonitorState? state) {
  if (state == null || (!state.running && !state.starting)) {
    return (active: false, tooltip: '$kAppDisplayName\n未运行签到任务');
  }
  final task = state.config.courseWatch ? '课表值守' : '自动检测';
  final phase = !state.running
      ? '正在启动'
      : state.waitingForWindow
      ? '等待课表时段'
      : !state.discovering
      ? '正在处理签到'
      : state.consecutiveFailures > 0
      ? '获取失败，等待重试'
      : '正在检测签到';
  return (active: state.running, tooltip: '$kAppDisplayName\n$task：$phase');
}
