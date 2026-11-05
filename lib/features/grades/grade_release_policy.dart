import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';

class AcademicExamDates {
  const AcademicExamDates({
    required this.term,
    required this.at,
    required this.dates,
  });
  final String term;
  final DateTime at;
  final List<DateTime> dates;

  Map<String, dynamic> toJson() => {
    'term': term,
    'at': at.toIso8601String(),
    'dates': dates.map((d) => d.toIso8601String()).toList(),
  };
  static AcademicExamDates? parse(Object? value) {
    if (value is! Map) return null;
    try {
      return AcademicExamDates.fromJson(Map<String, dynamic>.from(value));
    } catch (_) {
      // Bad optional exam metadata must not discard otherwise usable grades.
      return null;
    }
  }

  factory AcademicExamDates.fromJson(Map<String, dynamic> json) =>
      AcademicExamDates(
        term: json['term'] as String,
        at: DateTime.parse(json['at'] as String),
        dates: (json['dates'] as List)
            .map((d) => DateTime.parse(d as String))
            .toList(),
      );
}

/// Exam facts permit checks shortly after an account's actual examinations.
/// Without them, only published term-end / vacation dates permit checks.
/// Estimated semester lengths and final class meetings are never exam dates.
bool gradeReleaseWindow(DateTime now, {AcademicExamDates? exams}) {
  final day = DateTime(now.year, now.month, now.day);
  if (exams != null && !exams.at.isAfter(now)) {
    for (final date in exams.dates) {
      final exam = DateTime(date.year, date.month, date.day);
      final elapsed = day.difference(exam).inDays;
      if (elapsed >= 1 && elapsed <= 14) return true;
    }
  }
  return academicTerms.values.any(
    (term) => day.isAfter(term.end) && !day.isAfter(term.gradeWindowEnd),
  );
}
