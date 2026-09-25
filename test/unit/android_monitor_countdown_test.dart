import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/platform/android_monitor_task.dart';

void main() {
  group('formatMonitorCountdown', () {
    final now = DateTime(2026, 9, 25, 12, 0, 0);

    test('null next → 即将检测', () {
      expect(formatMonitorCountdown(null, now: now), '即将检测');
    });

    test('past or now → 即将检测', () {
      expect(formatMonitorCountdown(now, now: now), '即将检测');
      expect(
        formatMonitorCountdown(now.subtract(const Duration(seconds: 5)), now: now),
        '即将检测',
      );
    });

    test('seconds only', () {
      expect(
        formatMonitorCountdown(now.add(const Duration(seconds: 18)), now: now),
        '下次检测约 18s',
      );
    });

    test('minutes and seconds', () {
      expect(
        formatMonitorCountdown(now.add(const Duration(seconds: 75)), now: now),
        '下次检测约 1:15',
      );
    });
  });
}
