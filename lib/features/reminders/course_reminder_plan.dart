/// One actual course meeting, including connected periods. The timetable's
/// arbitrary time-of-day anchor must be resolved to a real date first.
class ClassOccurrence {
  ClassOccurrence({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.courseTitle,
    required DateTime startsAt,
    required DateTime endsAt,
    this.location,
    this.timeZone = 'Asia/Shanghai',
  }) : startsAt = startsAt.toUtc(),
       endsAt = endsAt.toUtc() {
    if (id.isEmpty || userId <= 0 || !this.endsAt.isAfter(this.startsAt)) {
      throw ArgumentError(
        'A course occurrence needs an identity and a valid time range',
      );
    }
  }

  final String id;
  final int userId;
  final String courseId;
  final String courseTitle;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? location;
  final String timeZone;
}

class CourseReminder {
  const CourseReminder({required this.occurrence, required this.minutesBefore});
  final ClassOccurrence occurrence;
  final int minutesBefore;
  String get key => '${occurrence.userId}:${occurrence.id}:$minutesBefore';
  DateTime get firesAt =>
      occurrence.startsAt.subtract(Duration(minutes: minutesBefore));
  String get title =>
      '${occurrence.courseTitle}  还有${minutesBefore == 60 ? '1 小时' : '$minutesBefore 分钟'}开课';
  String get locationLabel => occurrence.location?.trim().isNotEmpty == true
      ? occurrence.location!.trim()
      : '地点待补充';
}

/// Pure planning: changing a class keeps its reminder keys stable so a platform
/// scheduler can replace old times. Past reminders are never replayed.
List<CourseReminder> planCourseReminders({
  required Iterable<ClassOccurrence> occurrences,
  required int userId,
  required DateTime now,
}) {
  final reminders = <String, CourseReminder>{};
  for (final occurrence in occurrences) {
    if (occurrence.userId != userId) continue;
    for (final minutes in const [60, 15]) {
      final reminder = CourseReminder(
        occurrence: occurrence,
        minutesBefore: minutes,
      );
      if (reminder.firesAt.isAfter(now)) reminders[reminder.key] = reminder;
    }
  }
  return reminders.values.toList()
    ..sort((a, b) => a.firesAt.compareTo(b.firesAt));
}

/// The future AlarmManager/local notification adapter is independent of polling.
/// Reconciliation must remove obsolete keys and replace changed trigger times.
abstract interface class CourseReminderScheduler {
  Future<void> reconcile(int userId, List<CourseReminder> reminders);
  Future<void> cancelAccount(int userId);
}
