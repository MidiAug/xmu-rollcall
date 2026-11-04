// Protocol evidence: api-reference/tronclass/homework-grading.md.
Map<String, dynamic> taMap(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('作业响应格式异常');
  }
  return value;
}

int taId(Object? value) {
  if (value is! int || value <= 0) {
    throw const FormatException('作业标识格式异常');
  }
  return value;
}

List<Map<String, dynamic>> taRows(Object? value, String key) {
  final list = taMap(value)[key];
  if (list is! List) throw const FormatException('作业列表格式异常');
  return list.map(taMap).toList();
}

double? taScore(Object? value) {
  if (value == null) return null;
  final score = value is num ? value.toDouble() : double.tryParse('$value');
  if (score == null || !score.isFinite) {
    throw const FormatException('成绩格式异常');
  }
  return score;
}

class TaAssignment {
  const TaAssignment({
    required this.id,
    required this.title,
    this.expected = 0,
    this.submitted = 0,
    this.graded = 0,
    this.canGrade = false,
  });
  factory TaAssignment.parse(Map<String, dynamic> j) => TaAssignment(
    id: taId(j['id']),
    title: j['title'] as String,
    expected: j['expected_submit_count'] as int? ?? 0,
    submitted: j['submitted_count'] as int? ?? 0,
    graded: j['scored_count'] as int? ?? 0,
    canGrade:
        j['submit_by_group'] == false &&
        j['score_type'] == 'percentage' &&
        (j['rubric_id'] == null || j['rubric_id'] == 0) &&
        j['is_review_homework'] != true &&
        taMap(j['data'])['mode'] == 'normal',
  );
  final int id, expected, submitted, graded;
  final String title;
  final bool canGrade;
}

class TaAssignmentSnapshot {
  const TaAssignmentSnapshot(this.items, this.checkedAt);
  final List<TaAssignment> items;
  final DateTime checkedAt;
}

class TaStudent {
  const TaStudent({
    required this.id,
    required this.number,
    required this.name,
    this.submitted = false,
    this.score,
    this.scoreChecked = false,
  });
  final int id;
  final String number, name;
  final bool submitted;
  final double? score;
  final bool scoreChecked;
}

class TaZip {
  const TaZip({required this.id, required this.status, this.key});
  factory TaZip.parse(Object? data) {
    final zip = taMap(data)['zip'];
    if (zip == null) return const TaZip(id: 0, status: 'none');
    final j = taMap(zip);
    final key = j['key'] as String?;
    if (key != null && !RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(key)) {
      throw const FormatException('打包下载地址格式异常');
    }
    return TaZip(id: taId(j['id']), status: j['status'] as String, key: key);
  }
  final int id;
  final String status;
  final String? key;
  Uri? get download => status == 'ready' && key != null
      ? Uri.https('c-media.xmu.edu.cn', '/download/file/$key')
      : null;
}

enum TaRowStatus { ready, saved, skipped, failed, uncertain }

class TaGradeRow {
  TaGradeRow({
    required this.line,
    required this.number,
    required this.score,
    this.student,
    this.issue,
  });
  final int line;
  final String number, score;
  final TaStudent? student;
  final String? issue;
  TaRowStatus status = TaRowStatus.ready;
  String? result;
}
