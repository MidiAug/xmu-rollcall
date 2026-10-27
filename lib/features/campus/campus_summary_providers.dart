import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/cache/cache_revisions.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';

final campusNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Minute-aligned UI clock. No HTTP or detection work; disposed with the panel.
final campusClockProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  Timer? timer;
  void tick() {
    final now = ref.read(campusNowProvider)();
    controller.add(now);
    timer = Timer(
      Duration(milliseconds: 60000 - now.millisecondsSinceEpoch % 60000),
      tick,
    );
  }

  tick();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

class CampusCachedData {
  const CampusCachedData({
    this.schedule,
    this.homework = const [],
    this.hasHomeworkCache = false,
  });
  final AcademicSchedule? schedule;
  final List<HomeworkItem> homework;
  final bool hasHomeworkCache;
}

/// Reads disk snapshots only. Mounting this summary cannot scan courses or log in.
final campusCachedDataProvider = FutureProvider.autoDispose<CampusCachedData>((
  ref,
) async {
  ref.watch(academicRevisionProvider);
  ref.watch(homeworkCacheRevisionProvider);
  final auth = ref.watch(authControllerProvider);
  final scope = ref.watch(selectedRollcallAccountProvider);
  final uid = scope ?? auth.profile?.id;
  if (!auth.isSignedIn || uid == null) return const CampusCachedData();
  final schedule = await AcademicScheduleStore.read(uid);
  final catalog = await CourseCatalogStore.read(uid);
  final studentIds = catalog?.courses
      .where((c) => !c.isTeaching)
      .map((c) => c.id)
      .toSet();
  final teachingIds =
      catalog?.courses.where((c) => c.isTeaching).map((c) => c.id).toSet() ??
      <String>{};
  final todos = await JsonDiskCache.readList('homework_todos_$uid');
  final items = <String, HomeworkItem>{};
  void collect(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final item = HomeworkItem.fromJson(row);
      if (!item.isHomework ||
          item.closed == true ||
          teachingIds.contains('${item.courseId}')) {
        continue;
      }
      if (studentIds != null &&
          item.courseId != null &&
          !studentIds.contains('${item.courseId}')) {
        continue;
      }
      final submission = item.status.toLowerCase();
      if (const {'submitted', 'graded', '已提交', '已批改'}.contains(submission)) {
        continue;
      }
      items['${item.courseId}/${item.id}'] = item;
    }
  }

  if (todos != null) collect(todos.items);
  return CampusCachedData(
    schedule: schedule,
    homework: items.values.toList(),
    hasHomeworkCache: todos != null,
  );
});
