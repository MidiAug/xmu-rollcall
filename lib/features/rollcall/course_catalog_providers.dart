import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository_providers.dart';

final courseCatalogProvider =
    AsyncNotifierProvider<CourseCatalogNotifier, CourseCatalogSnapshot?>(
  CourseCatalogNotifier.new,
);

/// Sticky CourseCatalog: disk first; network only on cold miss or explicit refresh.
class CourseCatalogNotifier extends AsyncNotifier<CourseCatalogSnapshot?> {
  int? _boundUserId;
  Future<CourseCatalogSnapshot>? _inFlight;

  @override
  Future<CourseCatalogSnapshot?> build() async {
    ref.keepAlive();
    final auth = ref.watch(authControllerProvider);
    final profile = auth.profile;
    if (!auth.isSignedIn || profile == null || profile.id == 0) {
      _boundUserId = null;
      _inFlight = null;
      return null;
    }
    _boundUserId = profile.id;
    final disk = await CourseCatalogStore.read(profile.id);
    if (disk != null) return disk;
    return _fetchAndPersist(profile.id);
  }

  /// Appear does **not** hit the network when disk exists (R-35 Sticky).
  Future<void> ensureFresh({
    EnsureFreshReason reason = EnsureFreshReason.appear,
  }) async {
    final uid = _boundUserId ?? ref.read(authControllerProvider).profile?.id;
    if (uid == null || uid == 0) return;
    if (reason == EnsureFreshReason.appear) {
      final disk = await CourseCatalogStore.read(uid);
      if (disk != null) {
        if (_boundUserId == uid) state = AsyncData(disk);
        return;
      }
    }
    await refresh();
  }

  Future<void> refresh() async {
    final uid = _boundUserId ?? ref.read(authControllerProvider).profile?.id;
    if (uid == null || uid == 0) return;
    final previous = state.valueOrNull;
    try {
      final next = await _fetchAndPersist(uid);
      if (_boundUserId != uid) return;
      state = AsyncData(next);
    } catch (e, st) {
      if (_boundUserId != uid) return;
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(e, st);
      }
    }
  }

  Future<CourseCatalogSnapshot> _fetchAndPersist(int userId) {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = () async {
      final snap =
          await ref.read(rollcallRepositoryProvider).fetchCourseCatalog();
      if (_boundUserId != userId) return snap;
      await CourseCatalogStore.write(userId, snap);
      return snap;
    }();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }
}
