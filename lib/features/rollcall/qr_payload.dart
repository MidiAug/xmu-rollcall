import 'dart:convert';

/// Normalize scanned / pasted QR content into TronClass `data` token.
String parseQrRollcallData(
  String raw, {
  int? expectedRollcallId,
  String? expectedCourseId,
  int depth = 0,
}) {
  if (depth > 3) throw const FormatException('二维码编码层数过多');
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('二维码内容为空');
  }

  if (trimmed.startsWith('{')) {
    final map = jsonDecode(trimmed);
    if (map is Map && map['data'] is String) {
      _checkQrIds(map, expectedRollcallId, expectedCourseId);
      final d = (map['data'] as String).trim();
      if (d.isNotEmpty) return d;
    }
    throw const FormatException('二维码未包含签到内容');
  }

  final asUri = Uri.tryParse(trimmed);
  if (asUri != null && asUri.queryParameters.containsKey('p')) {
    final fields = <String, dynamic>{};
    for (final part in asUri.queryParameters['p']!.split('!')) {
      final separator = part.indexOf('~');
      if (separator < 0) continue;
      final key = part.substring(0, separator);
      final value = part.substring(separator + 1);
      if (fields.containsKey(key)) throw const FormatException('二维码字段重复');
      fields[key] = value.startsWith('\x10')
          ? int.tryParse(value.substring(1), radix: 36)
          : value.replaceAll('\x1f', '~').replaceAll('\x1e', '!');
      if (fields[key] == null) {
        throw const FormatException('二维码字段格式不正确');
      }
    }
    _checkQrIds(
      {'courseId': fields['0'], 'rollcallId': fields['4']},
      expectedRollcallId,
      expectedCourseId,
    );
    final data = fields['3'];
    if (data is! String || data.trim().isEmpty) {
      throw const FormatException('二维码未包含签到内容');
    }
    return data.trim();
  }
  if (asUri != null &&
      (asUri.hasScheme || trimmed.contains('?')) &&
      asUri.queryParameters['data'] != null) {
    _checkQrIds(asUri.queryParameters, expectedRollcallId, expectedCourseId);
    final d = asUri.queryParameters['data']!.trim();
    if (d.isNotEmpty) return d;
  }

  // Some scanners wrap URL-encoded JSON.
  if (RegExp(r'%(?:7b|22|3a|2f)', caseSensitive: false).hasMatch(trimmed)) {
    final decoded = Uri.decodeComponent(trimmed);
    if (decoded != trimmed) {
      return parseQrRollcallData(
        decoded,
        expectedRollcallId: expectedRollcallId,
        expectedCourseId: expectedCourseId,
        depth: depth + 1,
      );
    }
  }
  if (asUri?.hasScheme == true ||
      trimmed.contains('?') ||
      RegExp(r'\s').hasMatch(trimmed)) {
    throw const FormatException('此内容不是签到二维码，请重新扫描');
  }
  return trimmed;
}

void _checkQrIds(
  Map fields,
  int? expectedRollcallId,
  String? expectedCourseId,
) {
  final rollcallId = fields['rollcallId'] ?? fields['rollcall_id'];
  final courseId = fields['courseId'] ?? fields['course_id'];
  if (expectedRollcallId != null &&
      rollcallId != null &&
      '$rollcallId' != '$expectedRollcallId') {
    throw const FormatException('二维码不属于本次签到，请重新扫描');
  }
  if (expectedCourseId != null &&
      courseId != null &&
      '$courseId' != expectedCourseId) {
    throw const FormatException('二维码不属于当前课程');
  }
}
