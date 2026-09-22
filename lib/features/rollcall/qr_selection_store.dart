import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers QR assist checkboxes per course (AC-ASSIST-05c).
class QrSelectionStore {
  QrSelectionStore(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String courseId) => 'qr_assist_sel_v1_$courseId';

  Future<QrSelectionSnapshot?> read(String courseId) async {
    if (courseId.isEmpty) return null;
    final raw = _prefs.getString(_key(courseId));
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
    if (courseId.isEmpty) return;
    await _prefs.setString(
      _key(courseId),
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
