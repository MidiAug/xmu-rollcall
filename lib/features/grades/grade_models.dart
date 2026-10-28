import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';

double? gradeNumber(Object? value) {
  final number = double.tryParse('$value');
  return number?.isFinite == true ? number : null;
}

class GradeRecord {
  const GradeRecord(this.data);
  final Map<String, dynamic> data;
  String get id => '${data['WID']}';
  String get title =>
      [data['XSKCM'], data['KCM']]
          .where((v) => v != null && '$v'.trim().isNotEmpty)
          .map((v) => '$v')
          .firstOrNull ??
      '未命名课程';
  String get term => '${data['XNXQDM'] ?? ''}';
  String get score =>
      [data['XSZCJMC'], data['ZCJ'], data['DJCJMC']]
          .where((v) => v != null && '$v'.trim().isNotEmpty)
          .map((v) => '$v')
          .firstOrNull ??
      '未公布';
  double get credits => gradeNumber(data['XF']) ?? 0;
  // XFJD is the course's grade point in the captured XMU grade application,
  // not credits multiplied by grade point. Preserve server honors points.
  double? get points => gradeNumber(data['JDF']) ?? gradeNumber(data['XFJD']);
  String get category => '${data['KCLBDM_DISPLAY'] ?? ''}';
  String get nature => '${data['KCXZDM_DISPLAY'] ?? ''}';
  bool get generalEducation => category.contains('通识');
  String? get exclusionReason {
    if ('${data['SFYX'] ?? '1'}' != '1') return '无效成绩';
    final type = '${data['DJCJLXDM_DISPLAY'] ?? ''}';
    final status = score.trim().toUpperCase();
    if ('${data['DJCJLXDM']}' == '200' ||
        type.contains('两级') ||
        const {'P', 'NP', '合格', '不合格', '通过', '不通过'}.contains(status)) {
      return '两级制不计绩点';
    }
    if (const {'W', 'DF', 'EX', '退课', '缓考', '免修'}.contains(status) ||
        const {'免修', '缓考', '退课'}.contains(type)) {
      return '免修、缓考或退课不计绩点';
    }
    if (credits <= 0) return '无有效学分';
    if (const [
      'JDF',
      'XFJD',
    ].any((key) => '${data[key]}'.trim().toUpperCase() == 'N/A')) {
      return '教务标记不计绩点';
    }
    if (points == null || points! < 0) return '教务未提供有效绩点';
    return null;
  }

  bool get eligible => exclusionReason == null;
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
  });
  final int version;
  final DateTime at;
  final String term;
  final List<GradeRecord> records;
  Map<String, dynamic> toJson() => {
    'version': version,
    'at': at.toIso8601String(),
    'term': term,
    'records': records.map((r) => r.data).toList(),
  };
  factory GradeSnapshot.fromJson(Map<String, dynamic> j) => GradeSnapshot(
    version: j['version'] as int? ?? 1,
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
    final score =
        gradeNumber(r.score) ??
        const <String, double>{
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
        }[r.score.trim().toUpperCase()];
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
