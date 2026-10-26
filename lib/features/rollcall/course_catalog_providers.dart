import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
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
    if (disk != null && disk.rolesResolved) return _withSchedules(userId, disk);
    if (disk != null) {
      try {
        return await _fetchAndPersist(userId);
      } catch (_) {
        return _withSchedules(userId, disk);
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
        final effective = await _withSchedules(uid, disk);
        if (_boundUserId == uid) state = AsyncData(effective);
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
      return _withSchedules(userId, snap);
    }();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<CourseCatalogSnapshot> _withSchedules(
    int uid,
    CourseCatalogSnapshot snap,
  ) async {
    final courses = <CatalogCourse>[];
    for (final course in snap.courses) {
      courses.add(
        course.withMeetings(await CourseScheduleStore.read(uid, course.id)),
      );
    }
    return CourseCatalogSnapshot(
      fetchedAt: snap.fetchedAt,
      courses: courses,
      semesterId: snap.semesterId,
      academicYearId: snap.academicYearId,
      rolesResolved: snap.rolesResolved,
    );
  }

  Future<void> saveMeetings(
    int userId,
    String courseId,
    List<CourseMeeting> meetings,
  ) async {
    if (_boundUserId != userId) throw StateError('账号已切换，请重新打开课表');
    final raw = await CourseCatalogStore.read(userId);
    if (raw == null ||
        !raw.courses.any((c) => c.id == courseId && !c.hasPlatformSchedule)) {
      throw StateError('课程安排已变化，请刷新课表');
    }
    if (_boundUserId != userId) throw StateError('账号已切换');
    await CourseScheduleStore.write(userId, courseId, meetings);
    final effective = await _withSchedules(userId, raw);
    if (_boundUserId == userId) state = AsyncData(effective);
  }
}
