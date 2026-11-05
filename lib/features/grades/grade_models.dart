import 'grade_release_policy.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';

double? gradeNumber(Object? value) {
  final number = double.tryParse('$value');
  return number?.isFinite == true ? number : null;
}

class GradeRecord {
  GradeRecord(Map<String, dynamic> source)
    : data = Map.unmodifiable(source),
      id = '${source['WID']}',
      title = _gradeText(source, const ['XSKCM', 'KCM'], '未命名课程'),
      term = '${source['XNXQDM'] ?? ''}',
      score = _gradeText(source, const ['XSZCJMC', 'ZCJ', 'DJCJMC'], '未公布'),
      credits = gradeNumber(source['XF']) ?? 0,
      points = gradeNumber(source['JDF']) ?? gradeNumber(source['XFJD']),
      category = '${source['KCLBDM_DISPLAY'] ?? ''}',
      nature = '${source['KCXZDM_DISPLAY'] ?? ''}',
      _valid = '${source['SFYX'] ?? '1'}' == '1',
      _scoreType = '${source['DJCJLXDM_DISPLAY'] ?? ''}',
      _scoreTypeCode = '${source['DJCJLXDM']}',
      _notCounted = const [
        'JDF',
        'XFJD',
      ].any((key) => '${source[key]}'.trim().toUpperCase() == 'N/A') {
    _status = score.trim().toUpperCase();
    numericScore = _numericGradeScore(
      score,
      source['GRADE_SYSTEM'] == 'graduate',
    );
  }

  final Map<String, dynamic> data;
  final String id, title, term, score, category, nature;
  final double credits;
  // XFJD is the course point, not credits multiplied by grade point.
  final double? points;
  final bool _valid, _notCounted;
  final String _scoreType, _scoreTypeCode;
  late final String _status;
  late final double? numericScore;
  bool get generalEducation => category.contains('通识');
  String? get exclusionReason {
    if (!_valid) return '无效成绩';
    final type = _scoreType;
    final status = _status;
    if (_scoreTypeCode == '200' ||
        type.contains('两级') ||
        const {'P', 'NP', '合格', '不合格', '通过', '不通过'}.contains(status)) {
      return '两级制不计绩点';
    }
    if (const {'W', 'DF', 'EX', '退课', '缓考', '免修'}.contains(status) ||
        const {'免修', '缓考', '退课'}.contains(type)) {
      return '免修、缓考或退课不计绩点';
    }
    if (credits <= 0) return '无有效学分';
    if (_notCounted) {
      return '教务标记不计绩点';
    }
    if (points == null || points! < 0) return '教务未提供有效绩点';
    return null;
  }

  bool get eligible => exclusionReason == null;
}

String _gradeText(
  Map<String, dynamic> source,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = source[key];
    if (value != null && '$value'.trim().isNotEmpty) return '$value';
  }
  return fallback;
}

double? _numericGradeScore(String score, bool graduate) {
  return gradeNumber(score) ??
      (graduate
          ? null
          : const <String, double>{
              'A+': 100,
              'A': 94,
              'A-': 89,
              'B+': 84,
              'B': 80,
              'B-': 77,
              'C+': 74,
              'C': 71,
              'C-': 67,
              'D': 63,
              'F': 59,
            }[score.trim().toUpperCase()]);
}

/// Grade application term codes differ from timetable semester codes.
class GradeTerm {
  const GradeTerm(this.raw, this.year, this.part);
  final String raw;
  final int year, part;
  static GradeTerm? parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{4})-([1239])$').firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    if (int.parse(match[2]!) != year + 1) return null;
    return GradeTerm(value, year, int.parse(match[3]!));
  }

  int get order => year * 4 + const {1: 0, 2: 1, 3: 2, 9: 3}[part]!;
  String get yearLabel => '$year—${year + 1}学年';
  String get label => part == 9
      ? '$year—${year + 1}短学期'
      : '${part == 1 ? year : year + 1}年${const {1: '秋季', 2: '春季', 3: '夏季'}[part]}学期';
}

enum GradeRange { all, year, recent, term }

List<String> gradeTerms(Iterable<GradeRecord> records) =>
    records.map((r) => r.term).where((t) => t.isNotEmpty).toSet().toList()
      ..sort(
        (a, b) => (GradeTerm.parse(b)?.order ?? -1).compareTo(
          GradeTerm.parse(a)?.order ?? -1,
        ),
      );

List<int> gradeYears(Iterable<GradeRecord> records) =>
    gradeTerms(records)
        .map(GradeTerm.parse)
        .whereType<GradeTerm>()
        .map((t) => t.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

List<GradeRecord> selectGradeRange(
  List<GradeRecord> records, {
  GradeRange range = GradeRange.all,
  String? term,
  int? year,
  Set<int> years = const {},
  int recentCount = 2,
}) {
  final recent = gradeTerms(records).take(recentCount).toSet();
  final selectedYears = {...years, ?year};
  return records
      .where(
        (r) => switch (range) {
          GradeRange.all => true,
          GradeRange.year => selectedYears.contains(
            GradeTerm.parse(r.term)?.year,
          ),
          GradeRange.recent => recent.contains(r.term),
          GradeRange.term => r.term == term,
        },
      )
      .toList();
}

class GradeSnapshot {
  const GradeSnapshot({
    required this.at,
    required this.term,
    required this.records,
    this.version = 2,
    this.education = 'undergraduate',
    this.exams,
  });
  final String education;
  final int version;
  final DateTime at;
  final String term;
  final List<GradeRecord> records;
  final AcademicExamDates? exams;
  Map<String, dynamic> toJson() => {
    if (exams != null) 'exams': exams!.toJson(),
    'version': version,
    'education': education,
    'at': at.toIso8601String(),
    'term': term,
    'records': records.map((r) => r.data).toList(),
  };
  factory GradeSnapshot.fromJson(Map<String, dynamic> j) => GradeSnapshot(
    exams: AcademicExamDates.parse(j['exams']),
    version: j['version'] as int? ?? 1,
    education: j['education'] as String? ?? 'undergraduate',
    at: DateTime.parse(j['at'] as String),
    term: j['term'] as String,
    records: (j['records'] as List)
        .map((r) => GradeRecord(Map<String, dynamic>.from(r as Map)))
        .toList(),
  );
}

bool useRecentGrades(GradeSnapshot? cache, DateTime now) {
  if (cache == null) return false;
  int? index(String term) => RegExp(r'^\d{4}[123]$').hasMatch(term)
      ? int.parse(term.substring(0, 4)) * 3 + int.parse(term[4])
      : null;
  final current = index(currentSemester(now)), previous = index(cache.term);
  return current != null &&
      previous != null &&
      current >= previous &&
      current - previous <= 2;
}

List<GradeRecord> mergeRecentGrades(
  List<GradeRecord> old,
  List<GradeRecord> fresh,
  Set<String> replacedTerms,
) {
  final replaced = {...replacedTerms, ...fresh.map((r) => r.term)};
  return {
    for (final r in old)
      if (!replaced.contains(r.term)) r.id: r,
    for (final r in fresh) r.id: r,
  }.values.toList();
}

({double credits, double? gpa, double? average}) calculateGpa(
  Iterable<GradeRecord> records,
) {
  var credits = 0.0, weighted = 0.0, scoreCredits = 0.0, scoreTotal = 0.0;
  for (final r in records.where((r) => r.eligible)) {
    credits += r.credits;
    weighted += r.credits * r.points!;
    final score = r.numericScore;
    if (score != null) {
      scoreCredits += r.credits;
      scoreTotal += score * r.credits;
    }
  }
  return (
    credits: credits,
    gpa: credits > 0 ? weighted / credits : null,
    average: scoreCredits > 0 ? scoreTotal / scoreCredits : null,
  );
}
