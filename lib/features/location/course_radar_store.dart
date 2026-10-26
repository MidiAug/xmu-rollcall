import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';

String? courseRadarPreferencesKey(int? ownerId, int? assistUserId) {
  if (ownerId == null || ownerId <= 0) return null;
  return assistUserId == null
      ? 'course_radar_defaults_$ownerId'
      : 'course_radar_defaults_${ownerId}_assist_$assistUserId';
}

/// Read the persisted snapshot in either the UI or the Android worker isolate.
/// Automatic submission never falls back to a course title or another account.
Future<CourseRadarPref?> readAutomaticRadarLocation({
  required int ownerId,
  required int? assistUserId,
  required String? courseId,
}) async {
  final key = courseRadarPreferencesKey(ownerId, assistUserId);
  final id = courseId?.trim() ?? '';
  if (key == null || id.isEmpty) return null;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final raw = prefs.getString(key);
  if (raw == null) return null;
  try {
    final map = jsonDecode(raw) as Map;
    final entry = map['id:$id'] ?? map[id];
    if (entry is! Map) return null;
    final pref = CourseRadarPref.fromJson(Map<String, dynamic>.from(entry));
    if (pref.courseId != id) return null;
    if (pref.placeId.isNotEmpty) {
      final saved = prefs.getString(savedRadarLocationsKey);
      if (saved == null) return null;
      final places = jsonDecode(saved);
      if (places is! List) return null;
      final matches = places.whereType<Map>().where(
        (p) => p['id'] == pref.placeId,
      );
      if (matches.length != 1) return null;
      final place = SavedLocation.fromJson(
        Map<String, dynamic>.from(matches.single),
      );
      validateRadarLocation(
        latitude: place.latitude,
        longitude: place.longitude,
        accuracy: place.accuracy,
      );
      // Automatic use follows the exact current place, never a deleted snapshot
      // or a different nearby/name-matched place. Manual confirmation may retain
      // the old snapshot as a visible suggestion.
      return CourseRadarPref(
        courseTitle: pref.courseTitle,
        courseId: pref.courseId,
        latitude: place.latitude,
        longitude: place.longitude,
        accuracy: place.accuracy,
        placeId: place.id,
        obtainedVia: RadarObtainedVia.place.storageKey,
        labelSnapshot: place.note,
        userConfigured: pref.userConfigured,
      );
    }
    validateRadarLocation(
      latitude: pref.latitude,
      longitude: pref.longitude,
      accuracy: pref.accuracy,
    );
    return pref;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  } on ArgumentError {
    return null;
  }
}
