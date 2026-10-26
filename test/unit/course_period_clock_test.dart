import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/settings/course_period_clock.dart';

void main() {
  test(
    'clock covers all eleven periods and includes long breaks in meetings',
    () {
      final clock = coursePeriodClock();
      expect(clock.keys, List.generate(11, (i) => i + 1));
      expect(clock[1]!.start, 480);
      expect(clock[3]!.end, 655);
      expect(clock[5]!.start, 870);
      expect(clock[6]!.end, 970);
      expect(periodTimeLabel(clock[11]!.end), '21:45');
    },
  );
  test('fixed time does not depend on platform or locally entered courses', () {
    expect(coursePeriodClock()[9], (start: 1150, end: 1195));
    final changed = coursePeriodClock();
    changed[9] = (start: 1160, end: 1205);
    expect(coursePeriodClock()[9], (start: 1150, end: 1195));
  });
}
