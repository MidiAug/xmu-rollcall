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
      [data['ZCJ'], data['DJCJMC']]
          .where((v) => v != null && '$v'.trim().isNotEmpty)
          .map((v) => '$v')
          .firstOrNull ??
      '未公布';
  double get credits => gradeNumber(data['XF']) ?? 0;
  double? get points =>
      gradeNumber(data['JDF']) ??
      (credits > 0 && gradeNumber(data['XFJD']) != null
          ? gradeNumber(data['XFJD'])! / credits
          : null);
  bool get eligible =>
      credits > 0 &&
      points != null &&
      points! >= 0 &&
      '${data['SFYX'] ?? '1'}' == '1';
}

class GradeSnapshot {
  const GradeSnapshot({
    required this.at,
    required this.term,
    required this.records,
  });
  final DateTime at;
  final String term;
  final List<GradeRecord> records;
  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'term': term,
    'records': records.map((r) => r.data).toList(),
  };
  factory GradeSnapshot.fromJson(Map<String, dynamic> j) => GradeSnapshot(
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
    final score = gradeNumber(r.score);
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
