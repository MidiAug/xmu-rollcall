import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/grades/grade_models.dart';
import 'package:xmu_rollcall/features/grades/grade_release_policy.dart';
import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';

void main() {
  test(
    'published calendar lengths vary; defaults never authorize requests',
    () {
      expect(
        [
          for (final year in [2022, 2023, 2024, 2025, 2026])
            [
              for (final season in [1, 2, 3]) semesterWeeks('$year$season'),
            ],
        ],
        [
          [18, 18, 5],
          [18, 17, 4],
          [19, 18, 3],
          [19, 17, 3],
          [18, 17, 3],
        ],
      );
      expect(
        [
          for (final season in [1, 2, 3]) semesterWeeks('2030$season'),
        ],
        [18, 17, 3],
      );
      expect(gradeReleaseWindow(DateTime(2030, 12, 31)), isFalse);
      expect(gradeReleaseWindow(DateTime(2031, 7, 15)), isFalse);
    },
  );

  test(
    'no fixed week sixteen, exact holiday boundaries and short-term grades',
    () {
      expect(gradeReleaseWindow(DateTime(2026, 12, 21)), isFalse);
      expect(gradeReleaseWindow(DateTime(2027, 1, 9)), isFalse);
      expect(gradeReleaseWindow(DateTime(2027, 1, 10)), isTrue);
      expect(gradeReleaseWindow(DateTime(2027, 2, 13)), isTrue);
      expect(gradeReleaseWindow(DateTime(2027, 2, 15)), isFalse);
      expect(gradeReleaseWindow(DateTime(2027, 6, 12)), isFalse);
      expect(gradeReleaseWindow(DateTime(2027, 6, 13)), isTrue);
      expect(gradeReleaseWindow(DateTime(2027, 7, 15)), isTrue);
      expect(gradeReleaseWindow(DateTime(2027, 9, 4)), isTrue);
      expect(gradeReleaseWindow(DateTime(2027, 9, 7)), isFalse);
    },
  );

  test('account exam facts allow early exams, not future or ancient ones', () {
    final exams = AcademicExamDates(
      term: '20261',
      at: DateTime(2026, 10, 1),
      dates: [DateTime(2026, 10, 30)],
    );
    expect(gradeReleaseWindow(DateTime(2026, 10, 29), exams: exams), isFalse);
    expect(gradeReleaseWindow(DateTime(2026, 10, 30), exams: exams), isFalse);
    expect(gradeReleaseWindow(DateTime(2026, 10, 31), exams: exams), isTrue);
    expect(gradeReleaseWindow(DateTime(2026, 11, 13), exams: exams), isTrue);
    expect(gradeReleaseWindow(DateTime(2026, 11, 14), exams: exams), isFalse);
    final cached = GradeSnapshot(
      at: exams.at,
      term: exams.term,
      records: [],
      exams: exams,
    );
    expect(GradeSnapshot.fromJson(cached.toJson()).exams!.dates, exams.dates);
    expect(
      GradeSnapshot.fromJson({
        ...cached.toJson(),
        'exams': {'term': null},
      }).exams,
      isNull,
    );
  });
}
