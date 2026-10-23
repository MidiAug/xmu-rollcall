import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/platform/android_monitor_shell.dart';

void main() {
  const discovery = AndroidNotificationChannel(
    'monitor_discovery',
    '发现',
    importance: Importance.high,
    enableVibration: true,
    playSound: false,
  );
  const quiet = AndroidNotificationChannel(
    'monitor_ongoing',
    '检测',
    importance: Importance.high,
    enableVibration: false,
    playSound: false,
  );
  test('vibration-only preferences do not demand more switches', () {
    const status = AndroidDiscoveryNotificationStatus(
      enabled: true,
      channel: discovery,
      ongoingChannel: quiet,
    );
    expect(status.discoveryBlocked, false);
    expect(status.ongoingAlerts, false);
  });
  test(
    'app denial blocks; sound-only preferences permit actual delivery testing',
    () {
      const denied = AndroidDiscoveryNotificationStatus(
        enabled: false,
        channel: discovery,
      );
      const noVibration = AndroidDiscoveryNotificationStatus(
        enabled: true,
        channel: AndroidNotificationChannel(
          'monitor_discovery',
          '发现',
          importance: Importance.high,
          enableVibration: false,
        ),
      );
      expect(denied.discoveryBlocked, true);
      expect(noVibration.discoveryBlocked, false);
    },
  );
  test('old success cannot validate changed permission or system version', () {
    const before = AndroidDiscoveryNotificationStatus(
      enabled: true,
      channel: discovery,
      background: {'sdkInt': 36},
    );
    const denied = AndroidDiscoveryNotificationStatus(
      enabled: false,
      channel: discovery,
      background: {'sdkInt': 36},
    );
    const upgraded = AndroidDiscoveryNotificationStatus(
      enabled: true,
      channel: discovery,
      background: {'sdkInt': 37},
    );
    expect(before.settingsFingerprint, isNot(denied.settingsFingerprint));
    expect(before.settingsFingerprint, isNot(upgraded.settingsFingerprint));
  });
}
