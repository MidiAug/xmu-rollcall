/// Read-only homework models (TronClass todos / homework-activities).
class HomeworkItem {
  const HomeworkItem({
    required this.id,
    required this.title,
    this.courseId,
    this.courseName = '',
    this.type = '',
    this.status = '',
    this.dueAt,
    this.description = '',
    this.raw = const {},
    this.closed,
  });

  final int id;
  final String title;
  final int? courseId;
  final String courseName;
  final String type;
  final String status;
  final DateTime? dueAt;
  final String description;
  final Map<String, dynamic> raw;
  final bool? closed;

  bool get isHomework =>
      type.isEmpty ||
      ['homework', 'assignment', '作业'].any(type.toLowerCase().contains);

  bool get isOverdue {
    if (closed == true) return true;
    final d = dueAt;
    if (d == null) return false;
    return d.isBefore(DateTime.now());
  }

  String get dueLabel {
    final d = dueAt;
    if (d == null) return '无截止日期';
    final local = d.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }

  HomeworkItem copyWith({
    String? title,
    int? courseId,
    String? courseName,
    String? type,
    String? status,
    DateTime? dueAt,
    String? description,
    Map<String, dynamic>? raw,
    bool clearDueAt = false,
    bool? closed,
  }) {
    return HomeworkItem(
      id: id,
      title: title ?? this.title,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      type: type ?? this.type,
      status: status ?? this.status,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      description: description ?? this.description,
      raw: raw ?? this.raw,
      closed: closed ?? this.closed,
    );
  }

  factory HomeworkItem.fromJson(Map<String, dynamic> d) {
    final id = _asInt(d, const ['id', 'activity_id', 'activityId']) ?? 0;
    final title =
        _asString(d, const [
          'title',
          'name',
          'activity_title',
          'activity_name',
        ]) ??
        '';
    final courseId = _asInt(d, const ['course_id', 'courseId', 'cid']);
    final courseName =
        _asString(d, const [
          'course_name',
          'courseName',
          'course_title',
          'courseTitle',
        ]) ??
        '';
    final type = _asString(d, const ['type', 'activity_type', 'kind']) ?? '';
    final status =
        _asString(d, const [
          'status',
          'submit_status',
          'submission_status',
          'completion_status',
        ]) ??
        '';
    final dueAt = _asDate(d, const [
      'due_at',
      'end_time',
      'deadline',
      'closes_at',
      'submit_by',
      'end_date',
    ]);
    final description =
        _asString(d, const ['description', 'content', 'instruction', 'body']) ??
        '';
    return HomeworkItem(
      id: id,
      title: title,
      courseId: courseId,
      courseName: courseName,
      type: type,
      status: status,
      dueAt: dueAt,
      description: description,
      raw: d,
      closed: d['is_closed'] is bool ? d['is_closed'] as bool : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (courseId != null) 'course_id': courseId,
    'course_name': courseName,
    'type': type,
    'status': status,
    if (dueAt != null) 'due_at': dueAt!.toIso8601String(),
    'description': description,
    if (closed != null) 'is_closed': closed,
  };
}

int? _asInt(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.toInt();
    if (v is String) {
      final n = int.tryParse(v.trim());
      if (n != null) return n;
    }
  }
  return null;
}

String? _asString(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = '$v'.trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

DateTime? _asDate(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    if (v is num) {
      final n = v.toInt();
      if (n > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n);
      }
      if (n > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      }
    }
    if (v is String && v.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(v.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}
