class LogisticsChoice {
  const LogisticsChoice(
    this.id,
    this.label, {
    this.imageRequired = false,
    this.name = '',
    this.ids = const [],
  });
  final String id, label;
  final String name;
  final List<String> ids;
  String get leafName => name.isEmpty ? label : name;
  final bool imageRequired;
}

List<LogisticsChoice> logisticsChoices(Object? data) {
  if (data is! List) throw const FormatException('后勤选项格式异常');
  final result = <LogisticsChoice>[];
  void visit(List<dynamic> rows, List<String> parents, List<String> parentIds) {
    for (final item in rows) {
      if (item is! Map) throw const FormatException('后勤选项格式异常');
      final id = item['id'] ?? item['value'];
      final title = item['name'] ?? item['label'];
      if (id == null || title is! String || title.isEmpty) {
        throw const FormatException('后勤选项缺失名称');
      }
      final path = [...parents, title];
      final children = item['children'];
      if (children is List && children.isNotEmpty) {
        visit(children, path, [...parentIds, '$id']);
      } else {
        result.add(
          LogisticsChoice(
            '$id',
            path.join('/'),
            imageRequired: '${item['uploadStatus']}' == '1',
            name: title,
            ids: [...parentIds, '$id'],
          ),
        );
      }
    }
  }

  visit(data, [], []);
  return result;
}

Map<String, String> logisticsSettings(Object? value) {
  if (value is! List) throw const FormatException('后勤配置格式异常');
  return {
    for (final row in value)
      if (row is Map && row['code'] is String)
        row['code'] as String: '${row['value'] ?? ''}',
  };
}

String logisticsPlainText(Object? value) => value is String
    ? value
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .trim()
    : '';

class LogisticsFeedback {
  LogisticsFeedback(Map<String, dynamic> row)
    : id = row['id'] as String,
      title = row['postTitle'] as String,
      content = logisticsPlainText(row['content']),
      scope = '${row['serviceScopeName'] ?? ''}',
      type = '${row['typeName'] ?? ''}',
      time = '${row['createTime'] ?? ''}',
      deleted = '${row['ifDelete']}' == '1',
      replies = (row['replyCount'] as num?)?.toInt() ?? 0,
      images = '${row['images'] ?? ''}'
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList();
  final String id, title, content, scope, type, time;
  final bool deleted;
  final int replies;
  final List<String> images;
}
