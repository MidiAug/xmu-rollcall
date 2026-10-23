import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/platform/desktop_notifications.dart';
import 'package:xmu_rollcall/platform/desktop_notification_content.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

List<RollcallItem> _items(int count) => [
  for (var i = 0; i < count; i++)
    RollcallItem.fromJson({
      'rollcall_id': i + 1,
      'course_title': '示例课程${i + 1}',
      'is_radar': true,
    }),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DesktopNotifications notifications;
  var foreground = false;
  var overlayAvailable = true;
  var setupFails = false;
  var sendFails = false;
  var setupCalls = 0;
  final systemAlerts = <bool>[];
  final inAppAlerts = <String>[];
  setUp(() {
    foreground = false;
    overlayAvailable = true;
    setupFails = false;
    sendFails = false;
    setupCalls = 0;
    systemAlerts.clear();
    inAppAlerts.clear();
    notifications = DesktopNotifications(
      setup: () async {
        setupCalls++;
        if (setupFails) throw StateError('unavailable');
      },
      isForeground: () async => foreground,
      send: (body, test) async {
        if (sendFails) throw StateError('native show failed');
        systemAlerts.add(test);
      },
      showInApp: (body) {
        if (!overlayAvailable) return false;
        inAppAlerts.add(body);
        return true;
      },
    );
  });
  tearDown(() => notifications.dispose());

  test('foreground discovery uses the in-app overlay', () async {
    foreground = true;
    expect(await notifications.notify(_items(2)), isTrue);
    expect(inAppAlerts.single, contains('2'));
    expect(systemAlerts, isEmpty);
    expect(setupCalls, 0);
  });

  test(
    'background discovery initializes once and sends system alerts',
    () async {
      expect(await notifications.notify(_items(1)), isTrue);
      expect(await notifications.notify(_items(2)), isTrue);
      expect(systemAlerts, [false, false]);
      expect(inAppAlerts, isEmpty);
      expect(setupCalls, 1);
    },
  );

  test(
    'missing foreground overlay falls back to system notification',
    () async {
      foreground = true;
      overlayAvailable = false;
      expect(await notifications.notify(_items(1)), isTrue);
      expect(systemAlerts, [false]);
    },
  );

  test('test forces a system notification even in the foreground', () async {
    foreground = true;
    expect(await notifications.test(), isTrue);
    expect(systemAlerts, [true]);
    expect(inAppAlerts, isEmpty);
    expect(notifications.lastTestSentAt, isNotNull);
  });

  test('native show failure remains retryable', () async {
    sendFails = true;
    expect(await notifications.notify(_items(1)), isFalse);
    expect(notifications.error, isNotNull);
    sendFails = false;
    expect(await notifications.notify(_items(1)), isTrue);
    expect(systemAlerts, [false]);
    expect(notifications.error, isNull);
  });

  test('failed setup can recover on the next delivery', () async {
    setupFails = true;
    expect(await notifications.notify(_items(1)), isFalse);
    expect(notifications.ready, isFalse);
    expect(notifications.error, isNotNull);
    setupFails = false;
    expect(await notifications.notify(_items(1)), isTrue);
    expect(notifications.ready, isTrue);
    expect(setupCalls, 2);
  });

  test('concurrent setup shares one pending initialization', () async {
    notifications.dispose();
    final pending = Completer<void>();
    notifications = DesktopNotifications(
      setup: () {
        setupCalls++;
        return pending.future;
      },
      isForeground: () async => false,
      send: (_, _) async {},
      showInApp: (_) => false,
    );
    final first = notifications.initialize();
    final second = notifications.initialize();
    expect(setupCalls, 1);
    pending.complete();
    await Future.wait([first, second]);
    expect(notifications.ready, isTrue);
  });

  test(
    'delivery success does not claim user confirmation; retest clears it',
    () async {
      notifications.confirmTest();
      expect(notifications.lastTestConfirmedAt, isNull);
      await notifications.test();
      expect(notifications.lastTestConfirmedAt, isNull);
      notifications.confirmTest();
      expect(notifications.lastTestConfirmedAt, isNotNull);
      await notifications.test();
      expect(notifications.lastTestConfirmedAt, isNull);
    },
  );

  test('failed retest clears an earlier successful confirmation', () async {
    await notifications.test();
    notifications.confirmTest();
    expect(notifications.lastTestConfirmedAt, isNotNull);
    sendFails = true;
    expect(await notifications.test(), isFalse);
    expect(notifications.lastTestSentAt, isNull);
    expect(notifications.lastTestConfirmedAt, isNull);
    notifications.confirmTest();
    expect(notifications.lastTestConfirmedAt, isNull);
    sendFails = false;
    expect(await notifications.test(), isTrue);
    expect(notifications.lastTestSentAt, isNotNull);
    expect(notifications.lastTestConfirmedAt, isNull);
  });

  test(
    'automatic results update quietly in background and use overlay in foreground',
    () async {
      notifications.dispose();
      final quiet = <DesktopNotificationContent>[];
      notifications = DesktopNotifications(
        setup: () async {},
        isForeground: () async => foreground,
        send: (_, _) async {
          fail('Result should use the quiet sender');
        },
        sendQuiet: (body) async {
          quiet.add(body);
        },
        showInApp: (body) {
          inAppAlerts.add(body);
          return true;
        },
      );
      expect(await notifications.notifyResult(_items(1).single, true), true);
      expect(quiet.single.body, contains('成功'));
      foreground = true;
      expect(await notifications.notifyResult(_items(1).single, false), true);
      expect(inAppAlerts.single, contains('未成功'));
      expect(quiet, hasLength(1));
    },
  );
}
