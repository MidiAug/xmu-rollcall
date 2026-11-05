import 'ta_models.dart';

/// RFC-style quoted fields, including BOM, CRLF and embedded newlines.
List<TaGradeRow> parseTaCsv(String text, List<TaStudent> students) {
  text = text.replaceFirst(RegExp('^\uFEFF'), '');
  final records = <List<String>>[];
  var fields = <String>[];
  var field = StringBuffer();
  var quoted = false;
  var closed = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closed = true;
        }
      } else {
        field.write(c);
      }
    } else if (c == ',' || c == '\r' || c == '\n') {
      fields.add(field.toString());
      field = StringBuffer();
      closed = false;
      if (c != ',') {
        records.add(fields);
        fields = [];
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      }
    } else if (c == '"' && field.isEmpty && !closed) {
      quoted = true;
    } else {
      if (closed || c == '"') throw const FormatException('CSV 引号格式错误');
      field.write(c);
    }
  }
  if (quoted) throw const FormatException('CSV 引号未闭合');
  if (field.isNotEmpty || fields.isNotEmpty || closed) {
    records.add([...fields, field.toString()]);
  }
  if (records.isEmpty) throw const FormatException('CSV 为空');
  final header = records.first.map((v) => v.trim()).toList();
  if (header.length != 2 ||
      header.toSet().length != 2 ||
      !header.contains('user_no') ||
      !header.contains('score')) {
    throw const FormatException('CSV 需要且仅需要 user_no,score 两列');
  }
  final numberIndex = header.indexOf('user_no');
  final scoreIndex = header.indexOf('score');
  final byNumber = <String, List<TaStudent>>{};
  for (final student in students) {
    byNumber.putIfAbsent(student.number, () => []).add(student);
  }
  final counts = <String, int>{};
  for (final record in records.skip(1)) {
    if (record.length == 2) {
      final number = record[numberIndex].trim();
      counts[number] = (counts[number] ?? 0) + 1;
    }
  }
  final rows = <TaGradeRow>[];
  for (var i = 1; i < records.length; i++) {
    final record = records[i];
    if (record.every((v) => v.trim().isEmpty)) continue;
    final number = record.length == 2 ? record[numberIndex].trim() : '';
    final score = record.length == 2 ? record[scoreIndex].trim() : '';
    final matches = byNumber[number] ?? [];
    final numeric = double.tryParse(score);
    final issue = record.length != 2
        ? '列数不正确'
        : number.isEmpty
        ? '学号为空'
        : (counts[number] ?? 0) > 1
        ? '学号重复'
        : matches.length != 1
        ? '学号不存在或不唯一'
        : !RegExp(r'^\d+(\.\d+)?$').hasMatch(score) ||
              numeric == null ||
              !numeric.isFinite ||
              numeric < 0 ||
              numeric > 100
        ? '分数应为 0 至 100，空白不提交'
        : null;
    rows.add(
      TaGradeRow(
        line: i + 1,
        number: number,
        score: score,
        student: matches.length == 1 ? matches.single : null,
        issue: issue,
      ),
    );
  }
  if (rows.isEmpty) throw const FormatException('CSV 没有成绩行');
  return rows;
}
