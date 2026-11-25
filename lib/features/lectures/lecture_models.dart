import 'dart:convert';

Map<String, dynamic> lectureMap(Object? value) {
  if (value is String) value = jsonDecode(value);
  if (value is! Map) throw const FormatException('讲座数据格式异常');
  return Map<String, dynamic>.from(value);
}

String lectureText(Object? value) => value?.toString().trim() ?? '';
int lectureInt(Object? value) {
  final parsed = value is int ? value : int.tryParse(lectureText(value));
  if (parsed == null || parsed < 0) throw const FormatException('讲座数值格式异常');
  return parsed;
}

class LectureEntry {
  const LectureEntry({
    required this.id,
    required this.title,
    this.start = '',
    this.end = '',
    this.address = '',
    this.state = '',
    this.recordId = '',
  });
  final String id, title, start, end, address, state, recordId;
  factory LectureEntry.fromJson(Map<String, dynamic> v) {
    final id = lectureText(v['ActivityCategoryId'] ?? v['ID']);
    final title = lectureText(v['Name']);
    if (id.isEmpty || title.isEmpty) throw const FormatException('讲座记录缺少标识或标题');
    return LectureEntry(
      id: id,
      title: title,
      start: lectureText(v['BeginOn']),
      end: lectureText(v['EndOn']),
      address: lectureText(v['Address']),
      state: lectureText(v['State']),
      recordId: lectureText(v['Serial'] ?? v['ID']),
    );
  }
  // Imported sessions may share a category/title; keep their own serial and time.
  String get key => '$id/$recordId/$start/$end';
  Map<String, dynamic> toJson() => {
    'ID': id,
    'Name': title,
    'BeginOn': start,
    'EndOn': end,
    'Address': address,
    'State': state,
    'Serial': recordId,
  };
}

class LecturePage {
  const LecturePage(this.rows, this.total, this.nextPage, {this.successCount});
  final List<LectureEntry> rows;
  final int total;
  final int? nextPage, successCount;
  factory LecturePage.fromJson(Map<String, dynamic> v) {
    final raw = v['data'];
    if (raw is! List) throw const FormatException('讲座列表格式异常');
    final page = lectureInt(v['page']), size = lectureInt(v['pageSize']);
    final total = lectureInt(v['totalRow']);
    if (page < 1 || size < 1 || total < raw.length) {
      throw const FormatException('讲座分页格式异常');
    }
    return LecturePage(
      raw.map((e) => LectureEntry.fromJson(lectureMap(e))).toList(),
      total,
      raw.isNotEmpty && page * size < total ? page + 1 : null,
      successCount: v.containsKey('successCount')
          ? lectureInt(v['successCount'])
          : null,
    );
  }
  Map<String, dynamic> toJson() => {
    'data': rows.map((e) => e.toJson()).toList(),
    'totalRow': total,
    'nextPage': nextPage,
    'successCount': successCount,
  };
  factory LecturePage.fromCache(Map<String, dynamic> v) => LecturePage(
    (v['data'] as List)
        .map((e) => LectureEntry.fromJson(lectureMap(e)))
        .toList(),
    lectureInt(v['totalRow']),
    v['nextPage'] as int?,
    successCount: v['successCount'] as int?,
  );
}
