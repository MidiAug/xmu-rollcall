import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';

/// Drop in-memory remote views for the owner session (R-35 S0).
///
/// Disk mirrors are intentionally left intact.
void invalidateOwnerRemoteMemory(Ref ref) {
  _invalidateOwnerRemote(
    invalidate: ref.invalidate,
    clearSeen: () {
      ref.read(seenInProgressCourseIdsProvider.notifier).state = {};
    },
  );
}

/// WidgetRef variant (settings「清缓存」等).
void invalidateOwnerRemoteMemoryFromWidget(WidgetRef ref) {
  _invalidateOwnerRemote(
    invalidate: ref.invalidate,
    clearSeen: () {
      ref.read(seenInProgressCourseIdsProvider.notifier).state = {};
    },
  );
}

void _invalidateOwnerRemote({
  required void Function(ProviderOrFamily provider) invalidate,
  required void Function() clearSeen,
}) {
  invalidate(courseCatalogProvider);
  invalidate(courseHistoryProvider);
  invalidate(homeworkTodosProvider);
  invalidate(courseHomeworkProvider);
  invalidate(activeRollcallsProvider(null));
  invalidate(sessionPriorProvider);
  clearSeen();
}

/// Watches auth transitions and clears owner remote memory on logout / account switch.
///
/// Must be [ref.watch]ed once from the app shell so the listener stays alive.
final sessionLifecycleProvider = Provider<void>((ref) {
  ref.listen<AuthState>(authControllerProvider, (prev, next) {
    final wasIn = prev?.isSignedIn == true;
    final nowOut = !next.isSignedIn;
    final switched = prev?.profile?.id != null &&
        next.profile?.id != null &&
        prev!.profile!.id != next.profile!.id;
    if ((wasIn && nowOut) || switched) {
      invalidateOwnerRemoteMemory(ref);
    }
  });
});
