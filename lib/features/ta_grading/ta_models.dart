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

DateTime? _taOptionalDate(Object? value) =>
    value is String && value.trim().isNotEmpty
    ? DateTime.tryParse(value.trim())
    : null;

String formatTaAssignmentTime(DateTime value, {bool includeYear = false}) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final y = local.year;
  final m = two(local.month);
  final d = two(local.day);
  final h = two(local.hour);
  final min = two(local.minute);
  return '${includeYear ? '$y-' : ''}$m-$d $h:$min';
}

class TaAssignment {
  const TaAssignment({
    required this.id,
    required this.title,
    this.expected = 0,
    this.submitted = 0,
    this.graded = 0,
    this.canGrade = false,
    this.startTime,
    this.endTime,
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
    startTime: _taOptionalDate(j['start_time']),
    endTime: _taOptionalDate(j['end_time']),
  );
  final int id, expected, submitted, graded;
  final String title;
  final bool canGrade;
  final DateTime? startTime, endTime;

  List<(String, String)> get timeMetrics {
    final start = startTime?.toLocal();
    final end = endTime?.toLocal();
    final crossYear = start != null && end != null && start.year != end.year;
    return [
      if (start != null)
        ('开放', formatTaAssignmentTime(start, includeYear: crossYear)),
      if (end != null)
        ('截止', formatTaAssignmentTime(end, includeYear: crossYear)),
    ];
  }
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
    this.attachmentBytes,
  });
  final int id;
  final String number, name;
  final bool submitted;
  final double? score;
  final bool scoreChecked;
  final int? attachmentBytes;
  bool get hasAttachments => (attachmentBytes ?? 0) > 0;

  TaStudent withScore(double? value, {bool checked = true}) => TaStudent(
    id: id,
    number: number,
    name: name,
    submitted: submitted,
    score: value,
    scoreChecked: checked,
    attachmentBytes: attachmentBytes,
  );
}

String taAttachmentSize(int? bytes) {
  if (bytes == null) return '—';
  if (bytes == 0) return '无附件';
  if (bytes < 1024) return '$bytes B';
  var size = bytes.toDouble();
  var unit = 0;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')} ${units[unit]}';
}

class TaScoreRecord {
  const TaScoreRecord({
    required this.id,
    required this.createdAt,
    required this.score,
    this.oldScore,
    this.operatorName = '',
  });
  factory TaScoreRecord.parse(Map<String, dynamic> j) {
    final operator = j['operator_name'];
    if (operator != null && operator is! String) {
      throw const FormatException('评分记录操作人格式异常');
    }
    return TaScoreRecord(
      id: taId(j['id']),
      createdAt: DateTime.parse(j['created_at'] as String),
      score: taScore(j['final_score']),
      oldScore: taScore(j['old_final_score']),
      operatorName: operator as String? ?? '',
    );
  }
  final int id;
  final DateTime createdAt;
  final double? score, oldScore;
  final String operatorName;
}

class TaRosterSnapshot {
  const TaRosterSnapshot(this.students, this.checkedAt);
  final List<TaStudent> students;
  final DateTime checkedAt;
}

String? taPercentageScoreIssue(String score) {
  final value = double.tryParse(score);
  return !RegExp(r'^\d+(\.\d+)?$').hasMatch(score) ||
          value == null ||
          !value.isFinite ||
          value < 0 ||
          value > 100
      ? '分数应为 0 至 100，空白不提交'
      : null;
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
