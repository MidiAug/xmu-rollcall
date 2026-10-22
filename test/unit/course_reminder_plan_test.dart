import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/reminders/course_reminder_plan.dart';

void main() {
  final start = DateTime.utc(2026, 10, 12, 2);
  ClassOccurrence meeting({int user = 1, DateTime? startsAt}) =>
      ClassOccurrence(
        id: 'meeting-1',
        userId: user,
        courseId: 'math',
        courseTitle: '高等数学',
        startsAt: startsAt ?? start,
        endsAt: (startsAt ?? start).add(const Duration(minutes: 100)),
        location: '海韵 203',
      );
  test('one connected class has 60 and 15 minute reminders', () {
    final plan = planCourseReminders(
      occurrences: [meeting()],
      userId: 1,
      now: start.subtract(const Duration(hours: 2)),
    );
    expect(plan.map((r) => r.firesAt), [
      start.subtract(const Duration(hours: 1)),
      start.subtract(const Duration(minutes: 15)),
    ]);
    expect(plan.first.locationLabel, '海韵 203');
  });
  test(
    'filters other accounts, duplicate classes and passed trigger times',
    () {
      final plan = planCourseReminders(
        occurrences: [meeting(), meeting(), meeting(user: 2)],
        userId: 1,
        now: start.subtract(const Duration(minutes: 30)),
      );
      expect(plan, hasLength(1));
      expect(plan.single.minutesBefore, 15);
    },
  );
  test('rescheduled class keeps notification keys and moves trigger time', () {
    final now = start.subtract(const Duration(hours: 3));
    final before = planCourseReminders(
      occurrences: [meeting()],
      userId: 1,
      now: now,
    );
    final after = planCourseReminders(
      occurrences: [meeting(startsAt: start.add(const Duration(hours: 1)))],
      userId: 1,
      now: now,
    );
    expect(after.map((r) => r.key), before.map((r) => r.key));
    expect(
      after.first.firesAt.difference(before.first.firesAt),
      const Duration(hours: 1),
    );
  });
}
