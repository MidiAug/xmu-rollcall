/// Read only the requested rollcall's own code, never a neighbouring record.
String? findTimetableNumberCode(Object? data, {required int rollcallId}) {
  if (data is! Map || data['rollcalls'] is! List) {
    throw const FormatException('Invalid timetable rollcall list response');
  }
  for (final row in data['rollcalls'] as List) {
    if (row is! Map || '${row['id']}' != '$rollcallId') continue;
    final code = row['number_code'];
    if (code is! String && code is! int) return null;
    final value = '$code'.trim();
    return value.isEmpty ? null : value;
  }
  return null;
}

/// Legacy parser for archived student_rollcalls responses.
String? findNumberCode(Object? data, {int depth = 0, int maxDepth = 10}) {
  if (depth > maxDepth || data == null) return null;
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    final direct = map['number_code'];
    if (direct != null && '$direct'.trim().isNotEmpty) {
      return '$direct'.trim();
    }
    for (final value in map.values) {
      final nested = findNumberCode(
        value,
        depth: depth + 1,
        maxDepth: maxDepth,
      );
      if (nested != null) return nested;
    }
  } else if (data is List) {
    for (final item in data) {
      final nested = findNumberCode(item, depth: depth + 1, maxDepth: maxDepth);
      if (nested != null) return nested;
    }
  }
  return null;
}
