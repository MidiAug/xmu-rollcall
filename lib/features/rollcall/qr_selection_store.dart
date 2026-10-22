import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers QR assist checkboxes per owner user + course (AC-ASSIST-05c  R-35 S1).
class QrSelectionStore {
  QrSelectionStore(this._prefs, {required this.userId});

  final SharedPreferences _prefs;
  final int userId;

  static String _key(int userId, String courseId) =>
      'qr_assist_sel_v1_${userId}_$courseId';

  static String _legacyKey(String courseId) => 'qr_assist_sel_v1_$courseId';

  Future<QrSelectionSnapshot?> read(String courseId) async {
    if (courseId.isEmpty || userId == 0) return null;
    final key = _key(userId, courseId);
    var raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      final legacy = _prefs.getString(_legacyKey(courseId));
      if (legacy != null && legacy.isNotEmpty) {
        await _prefs.setString(key, legacy);
        await _prefs.remove(_legacyKey(courseId));
        raw = legacy;
      }
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final idsRaw = map['assistUserIds'];
      final ids = <int>{};
      if (idsRaw is List) {
        for (final e in idsRaw) {
          final n = (e as num?)?.toInt();
          if (n != null && n > 0) ids.add(n);
        }
      }
      return QrSelectionSnapshot(
        includeOwner: map['includeOwner'] as bool? ?? true,
        assistUserIds: ids,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String courseId, QrSelectionSnapshot snap) async {
    if (courseId.isEmpty || userId == 0) return;
    await _prefs.setString(
      _key(userId, courseId),
      jsonEncode({
        'includeOwner': snap.includeOwner,
        'assistUserIds': snap.assistUserIds.toList()..sort(),
      }),
    );
  }
}

class QrSelectionSnapshot {
  const QrSelectionSnapshot({
    required this.includeOwner,
    required this.assistUserIds,
  });

  final bool includeOwner;
  final Set<int> assistUserIds;
}
