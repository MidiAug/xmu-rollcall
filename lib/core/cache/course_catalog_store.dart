import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

/// One course in the sticky CourseCatalog (R-35 §4).
class CatalogCourse {
  const CatalogCourse({
    required this.id,
    required this.title,
    this.timetables = const {},
  });

  final String id;
  final String title;

  /// Weekday (1–7) → slots.
  final Map<int, List<TimetableSlot>> timetables;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (timetables.isNotEmpty)
          'timetables': {
            for (final e in timetables.entries)
              '${e.key}': [
                for (final s in e.value) timetableSlotToJson(s),
              ],
          },
      };

  factory CatalogCourse.fromJson(Map<String, dynamic> j) {
    final raw = j['timetables'];
    Map<int, List<TimetableSlot>> tables = const {};
    if (raw != null) {
      tables = parseTimetables(raw);
    }
    return CatalogCourse(
      id: '${j['id'] ?? ''}',
      title: j['title'] as String? ?? '',
      timetables: tables,
    );
  }
}

class CourseCatalogSnapshot {
  const CourseCatalogSnapshot({
    required this.fetchedAt,
    required this.courses,
    this.semesterId,
    this.academicYearId,
  });

  final DateTime fetchedAt;
  final List<CatalogCourse> courses;
  final String? semesterId;
  final String? academicYearId;

  Map<String, String> get titlesById => {
        for (final c in courses)
          if (c.id.isNotEmpty) c.id: c.title,
      };

  Map<String, Map<int, List<TimetableSlot>>> get timetablesByCourse => {
        for (final c in courses)
          if (c.timetables.isNotEmpty) c.id: c.timetables,
      };

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'courses': [for (final c in courses) c.toJson()],
        if (semesterId != null) 'semesterId': semesterId,
        if (academicYearId != null) 'academicYearId': academicYearId,
      };

  factory CourseCatalogSnapshot.fromJson(Map<String, dynamic> j) {
    final raw = j['courses'];
    final courses = <CatalogCourse>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          courses.add(CatalogCourse.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return CourseCatalogSnapshot(
      fetchedAt: DateTime.tryParse(j['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      courses: courses,
      semesterId: j['semesterId'] as String?,
      academicYearId: j['academicYearId'] as String?,
    );
  }
}

abstract final class CourseCatalogStore {
  static String suffix(int userId) => 'course_catalog_$userId';

  static Future<CourseCatalogSnapshot?> read(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(JsonDiskCache.key(suffix(userId)));
    if (raw == null || raw.isEmpty) return null;
    try {
      return CourseCatalogSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(int userId, CourseCatalogSnapshot snap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      JsonDiskCache.key(suffix(userId)),
      jsonEncode(snap.toJson()),
    );
  }
}

Map<String, dynamic> timetableSlotToJson(TimetableSlot s) {
  String hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return {
    'sequence': s.sequence,
    'start_time': hhmm(s.start),
    'end_time': hhmm(s.end),
  };
}
