import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository_providers.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';

final courseCatalogProvider =
    AsyncNotifierProvider<CourseCatalogNotifier, CourseCatalogSnapshot?>(
      CourseCatalogNotifier.new,
    );

final scopedCourseCatalogProvider =
    Provider.family<
      AsyncNotifierProvider<CourseCatalogNotifier, CourseCatalogSnapshot?>,
      int?
    >((ref, id) {
      if (id == null) return courseCatalogProvider;
      return AsyncNotifierProvider<
        CourseCatalogNotifier,
        CourseCatalogSnapshot?
      >(() => CourseCatalogNotifier(assistUserId: id));
    });

/// Sticky CourseCatalog: disk first; network only on cold miss or explicit refresh.
class CourseCatalogNotifier extends AsyncNotifier<CourseCatalogSnapshot?> {
  CourseCatalogNotifier({this.assistUserId});
  final int? assistUserId;
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
    final userId = assistUserId ?? profile.id;
    _boundUserId = userId;
    final disk = await CourseCatalogStore.read(userId);
    if (disk != null && disk.rolesResolved) return disk;
    if (disk != null) {
      try {
        return await _fetchAndPersist(userId);
      } catch (_) {
        return disk;
      }
    }
    return _fetchAndPersist(userId);
  }

  /// Appear does **not** hit the network when disk exists (R-35 Sticky).
  Future<void> ensureFresh({
    EnsureFreshReason reason = EnsureFreshReason.appear,
  }) async {
    final uid =
        _boundUserId ??
        assistUserId ??
        ref.read(authControllerProvider).profile?.id;
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
    final uid =
        _boundUserId ??
        assistUserId ??
        ref.read(authControllerProvider).profile?.id;
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
      if (assistUserId != null) {
        final identity = ref
            .read(assistControllerProvider)
            .identities
            .firstWhere((a) => a.userId == assistUserId);
        final service = await ref.read(assistServiceProvider.future);
        await service.ensureSession(identity);
      }
      final snap = await ref
          .read(
            assistUserId == null
                ? rollcallRepositoryProvider
                : rollcallRepositoryForProvider(assistUserId),
          )
          .fetchCourseCatalog();
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
