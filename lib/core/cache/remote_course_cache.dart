import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';

/// Remote snapshots only. Hand-entered meetings, term dates and places survive.
Future<void> clearRemoteCourseCache() async {
  await JsonDiskCache.clearAll();
  final prefs = await SharedPreferences.getInstance();
  const prefixes = [
    'academic_schedule_v1_',
    'academic_attempt_',
    'academic_failure_',
    'academic_calendar_missing_',
    'grades_v1_',
    'grade_attempt_',
    'exams_v1_',
  ];
  for (final key in prefs.getKeys().where(
    (key) => prefixes.any(key.startsWith),
  )) {
    await prefs.remove(key);
  }
}
