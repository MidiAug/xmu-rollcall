import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/place_matching.dart';
import 'package:xmu_rollcall/features/location/teaching_catalog.dart';

// Run the production App matcher, never a second implementation of its rules.
void main(List<String> args) {
  final input = File(
    args.isEmpty ? 'tools/location_picker/local/legacy/课表地点核对输入.json' : args[0],
  );
  final output = Directory(
    args.length > 1 ? args[1] : 'build/teaching-location-audit',
  )..createSync(recursive: true);
  final rows = (jsonDecode(input.readAsStringSync()) as Map)['rows'] as List;
  final counts = <String, int>{}, contextual = <String, int>{};
  final byFile = <String, Map<String, int>>{};
  final details = <Map<String, Object?>>[];
  for (final raw in rows) {
    final row = Map<String, dynamic>.from(raw as Map);
    final room = row['room'] as String;
    final places = <String>{
      if (room.trim().isNotEmpty) room.trim(),
      ...List<String>.from(
        row['places'] as List,
      ).where((v) => v.trim().isNotEmpty),
    };
    final campus = Campus.values
        .where((c) => c.label == '${row['campus']}校区')
        .firstOrNull;
    final resolved = <bool>[], scoped = <bool>[];
    for (final text in places) {
      final actual = matchCoursePlace(text, const []);
      final withContext = matchCoursePlace(
        text,
        const [],
        campus: campus,
        department: row['department'] as String,
      );
      resolved.add(actual != null);
      scoped.add(withContext != null);
      details.add({
        'file': row['file'],
        'sheet': row['sheet'],
        'row': row['row'],
        'original': text,
        'campus': row['campus'],
        'department': row['department'],
        'appPlaceId': actual?.id,
        'appName': actual?.note,
        'latitude': actual?.latitude,
        'longitude': actual?.longitude,
        'withContextPlaceId': withContext?.id,
      });
    }
    // Each original course row counts once, even when two columns use aliases.
    final status = places.isEmpty
        ? '空地点'
        : resolved.every((v) => v)
        ? '全部地点已定位'
        : resolved.any((v) => v)
        ? '部分地点已定位'
        : '未定位';
    final contextStatus = places.isEmpty
        ? '空地点'
        : scoped.every((v) => v)
        ? '全部地点已定位'
        : scoped.any((v) => v)
        ? '部分地点已定位'
        : '未定位';
    counts.update(status, (n) => n + 1, ifAbsent: () => 1);
    contextual.update(contextStatus, (n) => n + 1, ifAbsent: () => 1);
    (byFile[row['file'] as String] ??= {}).update(
      status,
      (n) => n + 1,
      ifAbsent: () => 1,
    );
  }
  final summary = {
    'catalogSha256': teachingCatalogSha256,
    'inputSha256': sha256.convert(input.readAsBytesSync()).toString(),
    'rows': rows.length,
    'appRoomOnly': counts,
    'withExplicitCampusAndDepartment': contextual,
    'byFile': byFile,
    'method':
        '调用生产 matchCoursePlace；App 当前可用原文与显式原文校区，不假设学生学院等于开课单位。对照栏额外传入课表抽取明确提供的校区及开课单位。未定位含线上、校外、说明句和歧义，不等同缺失校内楼栋。',
  };
  const encoder = JsonEncoder.withIndent('  ');
  File('${output.path}/coverage.json').writeAsStringSync(
    encoder.convert({'summary': summary, 'details': details}),
  );
  File(
    '${output.path}/summary.json',
  ).writeAsStringSync(encoder.convert(summary));
  String escape(Object? value) => const HtmlEscape().convert('$value');
  String table(Map<String, int> values) =>
      '<table><tr><th>结果</th><th>原始课表行数</th></tr>${values.entries.map((e) => '<tr><td>${escape(e.key)}</td><td>${e.value}</td></tr>').join()}</table>';
  File('${output.path}/coverage.html').writeAsStringSync(
    '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>App课表地点匹配验证</title>
<style>body{font:16px/1.7 system-ui;max-width:1050px;margin:36px auto;padding:0 24px;color:#243f38;background:#f7faf8}table{width:100%;border-collapse:collapse;background:white;margin:20px 0}td,th{padding:10px 14px;border-bottom:1px solid #dbe5df;text-align:left}h1{font-size:28px}h2{font-size:21px}a{color:#176c55}</style>
<h1>App课表地点匹配验证</h1><p>13学期，共 ${rows.length} 条原始课表记录。本报告直接调用生产 matchCoursePlace。</p>
<p>全部地点已定位表示该行上课教室与安排地点均可匹配。部分地点已定位常见于一行同时包含楼名、线上授课或说明文字；未定位也包含校外、待定和缺上下文的写法，不能直接当成缺失楼宇数量。</p>
<h2>App当前可用的地点原文</h2>${table(counts)}
<h2>对照：额外提供明确校区与开课单位</h2><p>这些字段来自原课表抽取；当前教务课次模型未可靠提供的字段不会在App里猜测补齐。</p>${table(contextual)}
<h2>各学期（App当前原文匹配）</h2><table><tr><th>课表</th><th>全部定位</th><th>部分定位</th><th>未定位</th><th>空地点</th></tr>${byFile.entries.map((e) => '<tr><td>${escape(e.key)}</td>${['全部地点已定位', '部分地点已定位', '未定位', '空地点'].map((k) => '<td>${e.value[k] ?? 0}</td>').join()}</tr>').join()}</table>
<p><a href="pending.csv">下载待核对的原文CSV</a>　<a href="coverage.json">完整匹配明细JSON</a></p><p>分区坐标优先，缺点时遵循已维护的分区关联、楼宇或明确楼群回退；轮廓参考点不自动采用。该验证不是坐标实测或真机验收。</p><details><summary>目录版本</summary><code>$teachingCatalogSha256</code></details></html>''',
  );
  final pending = details.where((r) => r['appPlaceId'] == null);
  const fields = [
    'file',
    'sheet',
    'row',
    'campus',
    'department',
    'original',
    'withContextPlaceId',
  ];
  String csv(Iterable<Object?> values) => values
      .map((v) => '"${(v ?? '').toString().replaceAll('"', '""')}"')
      .join(',');
  File('${output.path}/pending.csv').writeAsStringSync(
    '\uFEFF${[csv(fields), ...pending.map((r) => csv(fields.map((f) => r[f])))].join('\r\n')}',
  );
  stdout.writeln(encoder.convert(summary));
}
