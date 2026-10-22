import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/history_candidates.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';

/// A warm course mirror is refreshed by events, never by its age alone.
String? homeworkRefreshReason({
  required DiskCacheSnapshot? disk,
  required CatalogCourse? course,
  required Iterable<HomeworkItem> todos,
  required DateTime now,
}) {
  if (disk == null) return 'never_checked';
  final cached = <int, HomeworkItem>{};
  for (final row in disk.items) {
    final item = HomeworkItem.fromJson(row);
    cached[item.id] = item;
  }
  for (final item in cached.values) {
    final due = item.dueAt;
    if (due != null && due.isAfter(disk.fetchedAt) && !due.isAfter(now)) {
      return 'deadline_passed';
    }
  }
  for (final item in todos) {
    if ('${item.courseId}' != course?.id || !item.isHomework) continue;
    final old = cached[item.id];
    if (old == null ||
        item.title != old.title ||
        (item.dueAt != null &&
            (old.dueAt == null || !item.dueAt!.isAtSameMomentAs(old.dueAt!)))) {
      return 'todo_changed';
    }
  }
  if (course != null &&
      coursePeriodEndedBetween(course.timetables, disk.fetchedAt, now)) {
    return 'period_ended';
  }
  return null;
}
