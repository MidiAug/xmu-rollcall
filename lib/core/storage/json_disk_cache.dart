import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Disk envelope for stale-while-revalidate list caches (research/28).
class DiskCacheSnapshot {
  const DiskCacheSnapshot({
    required this.fetchedAt,
    required this.items,
  });

  final DateTime fetchedAt;
  final List<Map<String, dynamic>> items;

  bool isFresh(Duration ttl) {
    final age = DateTime.now().difference(fetchedAt);
    if (age.isNegative) return true;
    return age < ttl;
  }
}

/// Tiny JSON list cache on [SharedPreferences] — no Hive.
///
/// Keys use [keyPrefix]; logout clears the prefix.
abstract final class JsonDiskCache {
  static const keyPrefix = 'swr_v1_';

  static String key(String suffix) => '$keyPrefix$suffix';

  static Future<DiskCacheSnapshot?> readList(String suffix) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key(suffix));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final at = DateTime.tryParse(map['fetchedAt'] as String? ?? '');
      final itemsRaw = map['items'];
      if (at == null || itemsRaw is! List) return null;
      final items = <Map<String, dynamic>>[
        for (final e in itemsRaw)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
      return DiskCacheSnapshot(fetchedAt: at, items: items);
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeList(
    String suffix,
    List<Map<String, dynamic>> items, {
    DateTime? fetchedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final envelope = <String, dynamic>{
      'fetchedAt': (fetchedAt ?? DateTime.now()).toIso8601String(),
      'items': items,
    };
    await prefs.setString(key(suffix), jsonEncode(envelope));
  }

  static Future<void> remove(String suffix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key(suffix));
  }

  /// Drop all SWR / account-mirror entries (settings「清缓存」).
  ///
  /// Do **not** call on sign-out (R-35: disk mirrors survive logout).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(keyPrefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
