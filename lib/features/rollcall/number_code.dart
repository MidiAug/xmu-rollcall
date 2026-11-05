/// Read only the requested rollcall's own code, never a neighbouring record.
String? findTimetableNumberCode(Object? data, {required int rollcallId}) {
  return timetableNumberCodes(data)[rollcallId];
}

/// A timetable response already contains every returned activity's code.
Map<int, String?> timetableNumberCodes(Object? data) {
  if (data is! Map || data['rollcalls'] is! List) {
    throw const FormatException('Invalid timetable rollcall list response');
  }
  final result = <int, String?>{};
  for (final row in data['rollcalls'] as List) {
    if (row is! Map) continue;
    final id = int.tryParse('${row['id']}');
    if (id == null || id <= 0 || result.containsKey(id)) continue;
    final code = row['number_code'];
    final value = code is String || code is int ? '$code'.trim() : '';
    result[id] = value.isEmpty ? null : value;
  }
  return result;
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
