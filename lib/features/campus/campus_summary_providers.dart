import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/cache/cache_revisions.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/homework/homework_cache.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';

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
  ref.watch(homeworkSubmissionRevisionProvider);
  final auth = ref.watch(authControllerProvider);
  final scope = ref.watch(selectedRollcallAccountProvider);
  final uid = scope ?? auth.profile?.id;
  if (!auth.isSignedIn || uid == null) return const CampusCachedData();
  final schedule = await ref.watch(academicCachedScheduleProvider(uid).future);
  final rawCatalog = await CourseCatalogStore.read(uid);
  final catalog = rawCatalog == null
      ? null
      : projectAcademicCatalog(rawCatalog, schedule);
  final homework = await readCachedHomework(uid, catalog);
  final pending = <HomeworkItem>[];
  for (final item in homework.items) {
    if (!item.isHomework || item.closed == true || item.isSubmitted) continue;
    final submission = await JsonDiskCache.readList(
      'homework_submission_${uid}_${item.id}',
    );
    if (submission != null &&
        submission.items.isNotEmpty &&
        HomeworkSubmissionState.fromJson(submission.items.first).submission ==
            HomeworkSubmission.submitted) {
      continue;
    }
    pending.add(item);
  }
  return CampusCachedData(
    schedule: schedule,
    homework: pending,
    hasHomeworkCache: homework.hasCache,
  );
});
