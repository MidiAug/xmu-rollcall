import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/platform/desktop_shell.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_manager');
  final calls = <String>[];
  var minimized = false;
  var visible = true;
  var focused = true;
  setUp(() {
    calls.clear();
    minimized = false;
    visible = true;
    focused = true;
    DesktopShell.instance.trayAvailable.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'isMinimized') return minimized;
          if (call.method == 'isVisible') return visible;
          if (call.method == 'isFocused') return focused;
          if (call.method == 'restore') minimized = false;
          return null;
        });
  });
  tearDown(() {
    DesktopShell.instance.trayAvailable.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'tray action follows the actual running task and stays disabled when idle',
    () async {
      const trayChannel = MethodChannel('tray_manager');
      Map? sent;
      final shell = DesktopShell.instance;
      final previousState = shell.readMonitorState;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(trayChannel, (call) async {
            if (call.method == 'setContextMenu') sent = call.arguments as Map;
            return null;
          });
      addTearDown(() {
        shell.readMonitorState = previousState;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(trayChannel, null);
      });
      for (final running in [true, false]) {
        for (final watch in [true, false]) {
          shell.readMonitorState = () => MonitorState(
            running: running,
            config: MonitorConfig(courseWatch: watch),
          );
          await shell.updateTrayMenu();
          final items = (sent!['menu'] as Map)['items'] as List;
          final action = items.cast<Map>().singleWhere(
            (m) => m['key'] == 'stop',
          );
          expect(action['label'], running && watch ? '暂停值守' : '停止检测');
          expect(action['disabled'], !running);
        }
      }
    },
  );

  test(
    'opening a minimized window restores it before showing and focusing',
    () async {
      minimized = true;
      await DesktopShell.instance.showMainWindow();
      expect(calls.indexOf('restore'), lessThan(calls.indexOf('show')));
      expect(calls.indexOf('show'), lessThan(calls.indexOf('focus')));
      expect(minimized, isFalse);
    },
  );

  test(
    'unavailable tray minimizes instead of leaving an inaccessible window',
    () async {
      await DesktopShell.instance.hideToTray();
      expect(calls, ['minimize']);
    },
  );

  test(
    'test click restores current page; discovery click opens rollcall root',
    () async {
      final destinations = <AppDestination>[];
      void select(AppDestination destination, {bool popToRoot = false}) {
        expect(popToRoot, isTrue);
        destinations.add(destination);
      }

      ShellNavigation.instance.bind(select);
      addTearDown(() => ShellNavigation.instance.unbind(select));
      minimized = true;
      visible = false;
      await DesktopShell.instance.handleNotificationActivation(
        DesktopShell.testNotificationId,
      );
      expect(calls, containsAllInOrder(['restore', 'show', 'focus']));
      expect(destinations, isEmpty);
      calls.clear();
      await DesktopShell.instance.handleNotificationActivation(
        DesktopShell.discoveryNotificationId,
      );
      expect(calls, containsAllInOrder(['show', 'focus']));
      expect(destinations, [AppDestination.rollcall]);
    },
  );

  test('available tray hides the window', () async {
    DesktopShell.instance.trayAvailable.value = true;
    await DesktopShell.instance.hideToTray();
    expect(calls, ['hide']);
  });

  test(
    'only a visible, restored, focused window suppresses system alerts',
    () async {
      final isForeground = DesktopShell.instance.notifications.isForeground;
      expect(await isForeground(), isTrue);
      minimized = true;
      expect(await isForeground(), isFalse);
      minimized = false;
      focused = false;
      expect(await isForeground(), isFalse);
      focused = true;
      visible = false;
      expect(await isForeground(), isFalse);
    },
  );
}
