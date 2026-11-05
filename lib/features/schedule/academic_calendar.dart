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
class AcademicTermDates {
  const AcademicTermDates(
    this.term,
    this.monday,
    this.end,
    this.gradeWindowEnd,
  );
  final String term;
  final DateTime monday;
  final DateTime end;
  // Spring results may arrive during the short term and summer vacation.
  final DateTime gradeWindowEnd;
  int get weeks => (end.difference(monday).inDays ~/ 7) + 1;
}

// Annual maintenance entry point. Dates are published calendar facts, not
// inferred exam dates. First week Monday is distinct from registration Sunday.
// Sources: https://dblab.xmu.edu.cn/topic/share/school-calendar/
final academicTerms = <String, AcademicTermDates>{
  for (final row in [
    (
      '20221',
      DateTime(2022, 9, 12),
      DateTime(2023, 1, 14),
      DateTime(2023, 2, 11),
    ),
    (
      '20222',
      DateTime(2023, 2, 13),
      DateTime(2023, 6, 17),
      DateTime(2023, 9, 9),
    ),
    (
      '20223',
      DateTime(2023, 6, 19),
      DateTime(2023, 7, 22),
      DateTime(2023, 9, 9),
    ),
    (
      '20231',
      DateTime(2023, 9, 11),
      DateTime(2024, 1, 13),
      DateTime(2024, 2, 24),
    ),
    (
      '20232',
      DateTime(2024, 2, 26),
      DateTime(2024, 6, 22),
      DateTime(2024, 8, 31),
    ),
    (
      '20233',
      DateTime(2024, 6, 24),
      DateTime(2024, 7, 20),
      DateTime(2024, 8, 31),
    ),
    (
      '20241',
      DateTime(2024, 9, 2),
      DateTime(2025, 1, 11),
      DateTime(2025, 2, 15),
    ),
    (
      '20242',
      DateTime(2025, 2, 17),
      DateTime(2025, 6, 21),
      DateTime(2025, 8, 30),
    ),
    (
      '20243',
      DateTime(2025, 6, 23),
      DateTime(2025, 7, 12),
      DateTime(2025, 8, 30),
    ),
    (
      '20251',
      DateTime(2025, 9, 1),
      DateTime(2026, 1, 10),
      DateTime(2026, 2, 28),
    ),
    (
      '20252',
      DateTime(2026, 3, 2),
      DateTime(2026, 6, 27),
      DateTime(2026, 8, 29),
    ),
    (
      '20253',
      DateTime(2026, 6, 29),
      DateTime(2026, 7, 18),
      DateTime(2026, 8, 29),
    ),
    (
      '20261',
      DateTime(2026, 9, 7),
      DateTime(2027, 1, 9),
      DateTime(2027, 2, 13),
    ),
    (
      '20262',
      DateTime(2027, 2, 15),
      DateTime(2027, 6, 12),
      DateTime(2027, 9, 4),
    ),
    (
      '20263',
      DateTime(2027, 6, 14),
      DateTime(2027, 7, 3),
      DateTime(2027, 9, 4),
    ),
  ])
    row.$1: AcademicTermDates(row.$1, row.$2, row.$3, row.$4),
};

final _academicMondays = <String, DateTime>{
  for (final entry in academicTerms.entries) entry.key: entry.value.monday,
};
Map<String, DateTime> get academicMondays => _academicMondays;

// Display-only estimates for calendars not published/maintained yet. Never
// use these estimates to initiate automatic grade requests.
int defaultSemesterWeeks(String term) =>
    switch (term.length == 5 ? term[4] : '') {
      '1' => 18,
      '2' => 17,
      '3' => 3,
      _ => 18,
    };
int semesterWeeks(String term) =>
    academicTerms[term]?.weeks ?? defaultSemesterWeeks(term);

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
