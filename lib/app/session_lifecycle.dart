import 'package:xmu_rollcall/features/lectures/lecture_provider.dart';
import 'package:xmu_rollcall/features/lectures/lecture_requirement_provider.dart';
import 'package:xmu_rollcall/features/classrooms/classroom_providers.dart';
import 'package:xmu_rollcall/features/campus_card/electricity_provider.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_providers.dart';
import 'package:xmu_rollcall/core/cache/remote_course_cache.dart';
import 'package:xmu_rollcall/features/logistics/logistics_provider.dart';
import 'package:xmu_rollcall/core/cache/cache_revisions.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/exams/exam_providers.dart';
import 'package:xmu_rollcall/features/grades/grade_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_overview.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_providers.dart';

/// Auth transitions invalidate owner views without deleting disk snapshots.
void invalidateOwnerRemoteMemory(Ref ref) {
  ref.invalidate(campusCardInfoProvider);
  ref.invalidate(classroomProvider);
  ref.invalidate(lectureProvider);
  ref.invalidate(lectureRequirementProvider);
  ref.invalidate(electricityProvider);
  ref.invalidate(cachedElectricityProvider);
  ref.invalidate(campusCardCachedInfoProvider);
  ref.invalidate(courseCatalogProvider);
  ref.invalidate(courseHistoryProvider);
  ref.invalidate(homeworkTodosProvider);
  ref.invalidate(courseHomeworkProvider);
  ref.invalidate(activeRollcallsProvider(null));
  ref.invalidate(sessionPriorProvider);
  ref.read(seenInProgressCourseIdsProvider.notifier).state = {};
}

/// The explicit clear action covers owner and imported accounts.
Future<void> clearRemoteCourseData(WidgetRef ref) async {
  await clearRemoteCourseCache();
  if (!ref.context.mounted) return;
  ref.invalidate(logisticsProvider);
  ref.invalidate(campusCardInfoProvider);
  ref.invalidate(classroomProvider);
  ref.invalidate(lectureProvider);
  ref.invalidate(lectureRequirementProvider);
  ref.invalidate(electricityProvider);
  ref.invalidate(cachedElectricityProvider);
  ref.invalidate(campusCardCachedInfoProvider);
  ref.invalidate(taRepositoryProvider);
  ref.invalidate(courseCatalogProvider);
  ref.invalidate(scopedCourseCatalogProvider);
  ref.invalidate(courseHistoryProvider);
  ref.invalidate(scopedCourseHistoryProvider);
  ref.invalidate(homeworkTodosProvider);
  ref.invalidate(courseHomeworkProvider);
  ref.invalidate(activeRollcallsProvider);
  ref.invalidate(sessionPriorProvider);
  ref.invalidate(scopedSessionPriorProvider);
  ref.invalidate(importedSeenCourseIdsProvider);
  ref.read(seenInProgressCourseIdsProvider.notifier).state = {};
  ref.read(academicRevisionProvider.notifier).state++;
  ref.read(homeworkCacheRevisionProvider.notifier).state++;
  ref.read(lectureCacheRevisionProvider.notifier).state++;
  ref.invalidate(campusCachedDataProvider);
  ref.invalidate(homeworkOverviewProvider);
  ref.invalidate(homeworkSubmissionProvider);
  ref.invalidate(gradeSnapshotProvider);
  ref.invalidate(examSnapshotProvider);
}

/// Watches auth transitions and clears owner remote memory on logout / account switch.
///
/// Must be [ref.watch]ed once from the app shell so the listener stays alive.
final sessionLifecycleProvider = Provider<void>((ref) {
  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    final wasIn = prev?.isSignedIn == true;
    final nowOut = !next.isSignedIn;
    final switched =
        prev?.profile?.id != null &&
        next.profile?.id != null &&
        prev!.profile!.id != next.profile!.id;
    if ((wasIn && nowOut) || switched) {
      invalidateOwnerRemoteMemory(ref);
    }
  });
});
