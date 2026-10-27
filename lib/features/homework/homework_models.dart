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
    this.attachments = const [],
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
  final List<HomeworkAttachment> attachments;

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
    List<HomeworkAttachment>? attachments,
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
      attachments: attachments ?? this.attachments,
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
      attachments: parseHomeworkAttachments(d),
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
    if (attachments.isNotEmpty)
      'attachments': attachments.map((a) => a.toJson()).toList(),
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

/// Teacher-provided files only; never collects submission uploads.
class HomeworkAttachment {
  const HomeworkAttachment({required this.name, this.url, this.size});
  final String name;
  final Uri? url;
  final int? size;
  Map<String, dynamic> toJson() => {
    'name': name,
    if (url != null) 'url': '$url',
    if (size != null) 'size': size,
  };
}

Uri? homeworkLink(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  final resolved = Uri.parse('https://lnt.xmu.edu.cn/').resolveUri(uri);
  return resolved.scheme == 'https' &&
          resolved.host.isNotEmpty &&
          resolved.userInfo.isEmpty
      ? resolved
      : null;
}

List<HomeworkAttachment> parseHomeworkAttachments(Map<String, dynamic> data) {
  final files = data['attachments'] ?? data['uploads'] ?? data['files'];
  if (files is! List) return const [];
  return [
    for (final raw in files.whereType<Map>())
      HomeworkAttachment(
        name:
            '${raw['name'] ?? raw['file_name'] ?? raw['filename'] ?? '未命名附件'}',
        url: homeworkLink('${raw['download_url'] ?? raw['url'] ?? ''}'),
        size: raw['size'] is num ? (raw['size'] as num).toInt() : null,
      ),
  ];
}

/// Readable plain text for the platform's HTML descriptions. No HTML execution,
/// image requests or third-party embeds when a detail page is opened.
String homeworkDescriptionText(String source) {
  var text = source.replaceAll(
    RegExp(
      r'<(script|style)[^>]*>.*?</\1>',
      caseSensitive: false,
      dotAll: true,
    ),
    '',
  );
  text = text.replaceAll(
    RegExp(r'<br\s*/?>|</(?:p|div|li|h[1-6])>', caseSensitive: false),
    '\n',
  );
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {
    '&nbsp;': ' ',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&amp;': '&',
  };
  for (final e in entities.entries) {
    text = text.replaceAll(e.key, e.value);
  }
  text = text.replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|[0-9]+);'), (m) {
    final raw = m[1]!;
    final n = raw.startsWith('x')
        ? int.tryParse(raw.substring(1), radix: 16)
        : int.tryParse(raw);
    return n != null && n > 0 && n <= 0x10ffff ? String.fromCharCode(n) : m[0]!;
  });
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
