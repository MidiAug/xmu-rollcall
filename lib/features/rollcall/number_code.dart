/// Recursively find TronClass `number_code` in nested JSON (KrsMt / dangzitou).
String? findNumberCode(Object? data, {int depth = 0, int maxDepth = 10}) {
  if (depth > maxDepth || data == null) return null;
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    final direct = map['number_code'];
    if (direct != null && '$direct'.trim().isNotEmpty) {
      return '$direct'.trim();
    }
    for (final value in map.values) {
      final nested = findNumberCode(value, depth: depth + 1, maxDepth: maxDepth);
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
