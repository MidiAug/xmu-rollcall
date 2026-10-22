import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/platform/desktop_shell.dart';

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
