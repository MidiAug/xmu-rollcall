import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/grades/grade_models.dart';

GradeRecord record(
  String id,
  String term, {
  Map<String, dynamic> extra = const {},
}) => GradeRecord({
  'WID': id,
  'XNXQDM': term,
  'XF': 3,
  'XFJD': '3.7',
  'ZCJ': 87,
  ...extra,
});

void main() {
  test('grade boundary parses a stable typed snapshot once', () {
    final source = <String, dynamic>{
      'WID': 'one',
      'XF': '3',
      'XFJD': '3.7',
      'ZCJ': '87',
    };
    final grade = GradeRecord(source);
    source['XF'] = 1;
    source['XFJD'] = 0;
    expect(grade.credits, 3);
    expect(grade.points, 3.7);
    expect(grade.numericScore, 87);
    expect(grade.data['XF'], '3');
    expect(calculateGpa([grade]).gpa, closeTo(3.7, 1e-10));
  });
  test(
    'XMU XFJD is a course point; N/A and two-level grades never enter GPA',
    () {
      final normal = record('normal', '2025-2026-1');
      expect(normal.points, 3.7);
      final rows = [
        normal,
        record('fail', '2025-2026-1', extra: {'XF': 1, 'XFJD': '0', 'ZCJ': 50}),
        record('pass', '2025-2026-1', extra: {'DJCJLXDM': '200', 'XFJD': 4}),
        record('np', '2025-2026-1', extra: {'XSZCJMC': 'NP', 'XFJD': 0}),
        record('ex', '2025-2026-1', extra: {'XSZCJMC': 'EX', 'XFJD': 4}),
        record('na', '2025-2026-1', extra: {'XFJD': 'N/A', 'JDF': 3}),
        record('invalid', '2025-2026-1', extra: {'SFYX': '0'}),
      ];
      expect(rows.where((r) => r.eligible).length, 2);
      final result = calculateGpa(rows);
      expect(result.credits, 4);
      expect(result.gpa, closeTo(2.775, .000001));
    },
  );

  test(
    'general education with points and honors remain; each attempt counts',
    () {
      final rows = [
        record('one', '2024-2025-1', extra: {'KCH': 'same', 'XFJD': 0}),
        record('two', '2025-2026-1', extra: {'KCH': 'same', 'XFJD': 4}),
        record('general', '2025-2026-1', extra: {'KCLBDM_DISPLAY': '通识教育课程'}),
        record('honors', '2025-2026-1', extra: {'XFJD': 4.5}),
      ];
      expect(rows.every((r) => r.eligible), isTrue);
      expect(rows[2].generalEducation, isTrue);
      expect(calculateGpa(rows).gpa, closeTo(3.05, .000001));
      expect(
        calculateGpa([
          record('letter', '2025-2026-1', extra: {'ZCJ': null, 'DJCJMC': 'A-'}),
        ]).average,
        89,
      );
    },
  );

  test(
    'all, academic year, recent graded terms and one term use local records',
    () {
      final rows = [
        record('old', '2023-2024-1'),
        record('fall', '2025-2026-1'),
        record('spring', '2025-2026-2'),
        record('summer', '2025-2026-3'),
        record('short', '2025-2026-9'),
        record('latest', '2026-2027-1'),
      ];
      expect(selectGradeRange(rows).length, 6);
      expect(gradeYears(rows), [2026, 2025, 2023]);
      expect(
        selectGradeRange(rows, range: GradeRange.year, years: {2023}).single.id,
        'old',
      );
      expect(selectGradeRange(rows, range: GradeRange.year), isEmpty);
      expect(
        selectGradeRange(
          rows,
          range: GradeRange.year,
          years: {2025, 2026},
        ).length,
        5,
      );
      expect(
        selectGradeRange(rows, range: GradeRange.year, year: 2025).length,
        4,
      );
      expect(
        selectGradeRange(
          rows,
          range: GradeRange.recent,
          recentCount: 2,
        ).map((r) => r.id),
        ['short', 'latest'],
      );
      expect(
        selectGradeRange(
          rows,
          range: GradeRange.term,
          term: '2025-2026-2',
        ).single.id,
        'spring',
      );
      expect(GradeTerm.parse('2025-2026-2')!.label, '2026年春季学期');
      expect(GradeTerm.parse('2025-2027-1'), isNull);
      expect(
        GradeSnapshot.fromJson({
          'at': '2026-10-28',
          'term': '20261',
          'records': [],
        }).version,
        1,
      );
    },
  );
}
