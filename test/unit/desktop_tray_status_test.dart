import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/platform/desktop_shell.dart';
import 'package:xmu_rollcall/platform/desktop_tray_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('waiting, processing and retry retain the active task indicator', () {
    for (final watch in [false, true]) {
      final running = MonitorState(
        running: true,
        config: MonitorConfig(courseWatch: watch),
      );
      final task = watch ? '课表值守' : '自动检测';
      final phases = {
        running: '正在检测签到',
        running.copyWith(waitingForWindow: true): '等待课表时段',
        running.copyWith(discovering: false): '正在处理签到',
        running.copyWith(consecutiveFailures: 1): '获取失败，等待重试',
      };
      for (final entry in phases.entries) {
        final status = desktopTrayStatus(entry.key);
        expect(status.active, isTrue);
        expect(status.tooltip, endsWith('\n$task：${entry.value}'));
        expect(status.tooltip, isNot(contains('·')));
      }
      expect(
        desktopTrayStatus(running.copyWith(running: false)).active,
        isFalse,
      );
      expect(
        desktopTrayStatus(running.copyWith(running: false)).tooltip,
        endsWith('未运行签到任务'),
      );
      final starting = desktopTrayStatus(
        running.copyWith(running: false, starting: true),
      );
      expect(starting.active, isFalse);
      expect(starting.tooltip, endsWith('$task：正在启动'));
    }
  });

  test(
    'native tray changes icon on start/stop and only updates changed text',
    () async {
      const channel = MethodChannel('tray_manager');
      final calls = <MethodCall>[];
      final shell = DesktopShell.instance;
      final previous = shell.readMonitorState;
      var state = const MonitorState(config: MonitorConfig(courseWatch: true));
      shell.readMonitorState = () => state;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        shell.readMonitorState = previous;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await shell.updateTrayStatus(force: true);
      expect(calls.map((c) => c.method), ['setIcon', 'setToolTip']);
      expect(
        (calls.first.arguments as Map)['iconPath'],
        isNot(contains('_active')),
      );
      calls.clear();
      state = state.copyWith(running: true, waitingForWindow: true);
      await shell.updateTrayStatus();
      expect(calls.map((c) => c.method), ['setIcon', 'setToolTip']);
      expect(
        (calls.first.arguments as Map)['iconPath'],
        contains('tray_icon_active'),
      );
      expect((calls.last.arguments as Map)['toolTip'], endsWith('课表值守：等待课表时段'));
      calls.clear();
      await shell.updateTrayStatus();
      expect(calls, isEmpty);
      state = state.copyWith(waitingForWindow: false);
      await shell.updateTrayStatus();
      expect(calls.single.method, 'setToolTip');
      calls.clear();
      state = state.copyWith(running: false);
      await shell.updateTrayStatus();
      expect(calls.map((c) => c.method), ['setIcon', 'setToolTip']);
      expect(
        (calls.first.arguments as Map)['iconPath'],
        isNot(contains('_active')),
      );
      expect((calls.last.arguments as Map)['toolTip'], endsWith('未运行签到任务'));
    },
  );
}
