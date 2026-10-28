import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'dart:async';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
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

/// Same owner-catalog state as the My page; no extra refresh or assist scans.
final hasIncompleteCourseScheduleProvider = Provider<bool>((ref) {
  if (!ref.watch(authControllerProvider).isSignedIn) return false;
  return ref
          .watch(courseCatalogProvider)
          .valueOrNull
          ?.courses
          .any((c) => c.needsSchedule) ??
      false;
});

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
    ref.watch(academicRevisionProvider);
    final auth = ref.watch(authControllerProvider);
    final profile = auth.profile;
    if (!auth.isSignedIn || profile == null || profile.id == 0) {
      _boundUserId = null;
      _inFlight = null;
      return null;
    }
    final userId = assistUserId ?? profile.id;
    _boundUserId = userId;
    if (assistUserId == null) {
      unawaited(
        Future(() async {
          await ref.read(academicSyncProvider).sync(userId);
        }).catchError((Object _) {}),
      );
    }
    final disk = await CourseCatalogStore.read(userId);
    final academic = await AcademicScheduleStore.read(userId);
    if (disk != null &&
        disk.rolesResolved &&
        disk.startDatesResolved &&
        (academic == null || disk.academicTerm == academic.term)) {
      return _withSchedules(userId, disk);
    }
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
      if (assistUserId == null) {
        await ref.read(academicSyncProvider).sync(uid, force: true);
      }
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
      final fetched = await ref
          .read(
            assistUserId == null
                ? rollcallRepositoryProvider
                : rollcallRepositoryForProvider(assistUserId),
          )
          .fetchCourseCatalog();
      final academic = await AcademicScheduleStore.read(userId);
      final snap = CourseCatalogSnapshot(
        fetchedAt: fetched.fetchedAt,
        courses: fetched.courses,
        semesterId: fetched.semesterId,
        academicYearId: fetched.academicYearId,
        rolesResolved: fetched.rolesResolved,
        startDatesResolved: fetched.startDatesResolved,
        academicTerm: academic?.term,
      );
      if (_boundUserId != userId) return snap;
      final previous = await CourseCatalogStore.read(userId);
      await CourseCatalogStore.write(userId, snap);
      final term = academic?.term;
      if (fetched.courses.any((c) => c.startDate != null) &&
          (previous == null ||
              !previous.startDatesResolved ||
              (term != null &&
                  teachingMondayFromCourses(previous.courses, term) !=
                      teachingMondayFromCourses(fetched.courses, term)))) {
        ref.read(academicRevisionProvider.notifier).state++;
      }
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
    final academic = await AcademicScheduleStore.read(uid);
    final effective = academic == null ? courses : academic.apply(courses);
    return CourseCatalogSnapshot(
      fetchedAt: snap.fetchedAt,
      academicTerm: snap.academicTerm,
      courses: effective,
      academicOnlyCourses: academic?.displayOnlyCourses(effective) ?? const [],
      semesterId: snap.semesterId,
      academicYearId: snap.academicYearId,
      rolesResolved: snap.rolesResolved,
      startDatesResolved: snap.startDatesResolved,
    );
  }

  Future<void> saveMeetings(
    int userId,
    String courseId,
    List<CourseMeeting> meetings, {
    int? expectedOwnerId,
  }) async {
    void requireScope() {
      if (_boundUserId != userId ||
          (expectedOwnerId != null &&
              ref.read(authControllerProvider).profile?.id !=
                  expectedOwnerId)) {
        throw StateError('账号已切换，请重新打开课表');
      }
      if (assistUserId != null &&
          !ref
              .read(assistControllerProvider)
              .identities
              .any((i) => i.userId == assistUserId)) {
        throw StateError('协助身份已移除');
      }
    }

    requireScope();
    final raw = await CourseCatalogStore.read(userId);
    if (raw == null ||
        !raw.courses.any((c) => c.id == courseId && !c.hasPlatformSchedule)) {
      throw StateError('课程安排已变化，请刷新课表');
    }
    requireScope();
    await CourseScheduleStore.write(userId, courseId, meetings);
    final effective = await _withSchedules(userId, raw);
    requireScope();
    state = AsyncData(effective);
    ref.read(academicRevisionProvider.notifier).state++;
  }
}
