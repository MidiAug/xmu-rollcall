class AcademicCalendarUnavailable extends FormatException {
  const AcademicCalendarUnavailable(this.term) : super('请设置第一周起始日');
  final String term;
}

/// Published XMU teaching-week anchors, rather than registration Sundays.
/// Sources:
/// https://dblab.xmu.edu.cn/post/xmucalendar2026to2027/
/// https://dblab.xmu.edu.cn/wp-content/uploads/2025/06/厦门大学2025-2026学年校历-1.pdf
/// Outside these calendars, a persisted anchor or a non-clamped server week
/// (week >= 2) is required. Vacation/future terms may both report currentZc=1.
final academicMondays = <String, DateTime>{
  '20251': DateTime(2025, 9, 1),
  '20252': DateTime(2026, 3, 2),
  '20253': DateTime(2026, 6, 29),
  '20261': DateTime(2026, 9, 7),
  '20262': DateTime(2027, 2, 15),
  '20263': DateTime(2027, 6, 14),
};

DateTime academicMonday(
  String term,
  int week,
  DateTime now, {
  DateTime? cached,
}) {
  final known = academicMondays[term];
  if (known != null) return known;
  if (cached != null) return cached;
  if (week < 2 || week > 30) {
    throw AcademicCalendarUnavailable(term);
  }
  return DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1 + (week - 1) * 7));
}
