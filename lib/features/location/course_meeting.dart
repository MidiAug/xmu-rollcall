import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

DateTime radarActivityReferenceTime(RollcallItem item, DateTime observedAt) {
  for (final key in ['rollcall_time', 'created_at', 'start_time']) {
    final value = item.raw[key];
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed != null && !parsed.isAfter(observedAt)) return parsed.toLocal();
  }
  return observedAt;
}

String courseMeetingKey(int weekday, SessionBlock block) =>
    '$weekday:${block.startSequence}-${block.endSequence}:${minutesOfDay(block.coreStart)}-${minutesOfDay(block.coreEnd)}';

Map<String, String> courseMeetingLabels(CatalogCourse course) => {
  for (final day in course.timetables.entries)
    for (final block in courseMeetingBlocks(day.value))
      courseMeetingKey(
        day.key,
        block,
      ): '${weekdayLabel(day.key)} ${block.sectionLabel} ${formatHm(block.coreStart)}–${formatHm(block.coreEnd)}',
};

/// Resolve only a real weekly meeting; never infer a room from attendance history.
Future<String?> resolveRadarMeeting({
  required int ownerId,
  required int? assistUserId,
  required String? courseId,
  required DateTime at,
}) async {
  if (courseId == null || courseId.trim().isEmpty) return null;
  final uid = assistUserId ?? ownerId;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final catalog = await CourseCatalogStore.read(uid);
  final courses = catalog?.courses.where((c) => c.id == courseId.trim());
  if (courses == null || courses.length != 1) return null;
  final course = courses.single.withMeetings(
    await CourseScheduleStore.read(uid, courseId.trim()),
  );
  final local = at.toLocal();
  final slots = course.timetables[local.weekday];
  if (slots == null) return null;
  final block = resolveBlock(courseMeetingBlocks(slots), local);
  return block == null ? null : courseMeetingKey(local.weekday, block);
}
