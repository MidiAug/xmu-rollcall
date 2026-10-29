import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

/// Auth transitions invalidate owner views without deleting disk snapshots.
void invalidateOwnerRemoteMemory(Ref ref) {
  ref.invalidate(courseCatalogProvider);
  ref.invalidate(courseHistoryProvider);
  ref.invalidate(homeworkTodosProvider);
  ref.invalidate(courseHomeworkProvider);
  ref.invalidate(activeRollcallsProvider(null));
  ref.invalidate(sessionPriorProvider);
  ref.read(seenInProgressCourseIdsProvider.notifier).state = {};
}

/// The explicit clear action covers owner and imported accounts.
void invalidateRemoteCourseMemoryFromWidget(WidgetRef ref) {
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
