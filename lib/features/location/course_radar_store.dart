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
