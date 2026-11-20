import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/logging/fetch_log.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_candidates.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';
import 'package:xmu_rollcall/features/homework/homework_cache.dart';
import 'package:xmu_rollcall/core/cache/cache_revisions.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

final homeworkClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class HomeworkOverview {
  const HomeworkOverview(
    this.items, {
    this.failedCourses = 0,
    this.pendingRefresh = false,
  });
  final List<HomeworkItem> items;
  final int failedCourses;
  final bool pendingRefresh;
}

final homeworkOverviewProvider =
    AsyncNotifierProvider.autoDispose<
      HomeworkOverviewNotifier,
      HomeworkOverview
    >(HomeworkOverviewNotifier.new);

/// Only mounted by the visible homework page. Courses share the existing disk
/// mirrors, but are read serially without mounting persistent family providers.
class HomeworkOverviewNotifier
    extends AutoDisposeAsyncNotifier<HomeworkOverview> {
  static const checkTtl = CachePolicy.homeworkActiveFreshFor;
  int _revision = 0;
  int? _scope;
  int? _owner;
  DateTime? _checkedAt;
  Future<bool>? _refreshing;
  int? _workRevision;
  bool _active = true;

  @override
  Future<HomeworkOverview> build() async {
    ref.keepAlive();
    ref.onCancel(() {
      _active = false;
      _revision++;
      if (_refreshing != null) _checkedAt = null;
    });
    ref.onResume(() => _active = true);
    final revision = ++_revision;
    ref.onDispose(() => _revision++);
    ref.watch(
      authControllerProvider.select((s) => (s.isSignedIn, s.profile?.id)),
    );
    final auth = ref.read(authControllerProvider);
    _scope = ref.watch(selectedRollcallAccountProvider);
    _owner = auth.profile?.id;
    _checkedAt = null;
    if (!auth.isSignedIn || _owner == null) return const HomeworkOverview([]);
    if (!_active) return const HomeworkOverview([]);
    final cached = await _load(
      force: false,
      revision: revision,
      cacheOnly: true,
    );
    unawaited(
      Future<void>(() async {
        if (_revision == revision) await ensureFresh();
      }),
    );
    return cached;
  }

  void _check(int revision) {
    if (_revision != revision) throw StateError('作业页面或账号已切换');
  }

  Future<HomeworkOverview> _load({
    required bool force,
    required int revision,
    bool cacheOnly = false,
  }) async {
    final uid = _scope ?? _owner!;
    final scope = _scope;
    final repository = ref.read(homeworkRepositoryProvider);
    final merged = <HomeworkItem>[];
    CourseCatalogSnapshot? catalog;
    var failed = 0;
    var needsNetwork = false;
    var todos = <HomeworkItem>[];
    try {
      if (!cacheOnly) {
        await ref
            .read(homeworkTodosProvider.notifier)
            .ensureFresh(
              reason: force
                  ? EnsureFreshReason.pullToRefresh
                  : EnsureFreshReason.appear,
            );
      }
      _check(revision);
      todos = await ref.read(homeworkTodosProvider.future);
      final todoAt = ref.read(homeworkTodosProvider.notifier).lastUpdatedAt;
      if (todoAt == null ||
          DateTime.now().difference(todoAt) >= HomeworkTodosNotifier.ttl) {
        needsNetwork = true;
      }
      for (final item in todos) {
        merged.add(item);
      }
    } catch (_) {
      _check(revision);
      failed++;
    }
    final catalogProvider = ref.read(scopedCourseCatalogProvider(scope));
    try {
      catalog = await ref.read(catalogProvider.future);
      _check(revision);
      for (final course
          in catalog?.courses.where((c) => !c.isTeaching) ??
              <CatalogCourse>[]) {
        final cid = int.tryParse(course.id);
        if (cid == null) continue;
        final suffix = 'course_homework_${uid}_$cid';
        final disk = await JsonDiskCache.readList(suffix);
        _check(revision);
        List<HomeworkItem> items = [
          for (final json in disk?.items ?? <Map<String, dynamic>>[])
            HomeworkItem.fromJson(json),
        ];
        final reason = homeworkRefreshReason(
          disk: disk,
          course: course,
          todos: todos,
          now: DateTime.now(),
        );
        if (reason != null) needsNetwork = true;
        if (!cacheOnly && reason != null) {
          try {
            await prepareHomeworkSession(ref, scope);
            _check(revision);
            items = await FetchLog.run(
              event: 'homework.overview.course',
              trigger: reason,
              fields: {'userId': uid, 'courseId': cid},
              fetch: () => repository.fetchCourseHomework(cid),
            );
            _check(revision);
            await JsonDiskCache.writeList(suffix, [
              for (final item in items) item.toJson(),
            ]);
            _check(revision);
            ref.invalidate(courseHomeworkProvider(cid));
            ref.read(homeworkCacheRevisionProvider.notifier).state++;
          } catch (_) {
            _check(revision);
            failed++;
          }
          await Future<void>.delayed(CachePolicy.courseFetchGap);
          _check(revision);
        }
        for (final item in items) {
          final seeded = item.copyWith(courseId: cid, courseName: course.title);
          merged.add(seeded);
        }
      }
    } catch (_) {
      _check(revision);
      failed++;
    }
    final items = mergeHomeworkItems(merged, catalog)
      ..sort(
        (a, b) =>
            (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999)),
      );
    if (failed == 0 && (!cacheOnly || !needsNetwork)) {
      _checkedAt = ref.read(homeworkClockProvider)();
    }
    return HomeworkOverview(
      items,
      failedCourses: failed,
      pendingRefresh: cacheOnly && needsNetwork,
    );
  }

  /// False for a fresh snapshot or a check already owned by another caller.
  Future<bool> ensureFresh({bool force = false}) async {
    final existing = _refreshing;
    if (existing != null) {
      final revision = _workRevision;
      await existing;
      if (revision == _revision) return false;
    }
    _workRevision = _revision;
    final work = _refresh(force);
    _refreshing = work;
    try {
      return await work;
    } finally {
      if (identical(_refreshing, work)) _refreshing = null;
    }
  }

  Future<bool> _refresh(bool force) async {
    final revision = _revision;
    try {
      await future;
    } catch (_) {}
    if (revision != _revision) return false;
    if (_owner == null || !_active) return false;
    if (!force &&
        _checkedAt != null &&
        ref.read(homeworkClockProvider)().difference(_checkedAt!) < checkTtl) {
      return false;
    }
    final previous = state.valueOrNull;
    // A check (including a failed one) is throttled across tab switches.
    _checkedAt = ref.read(homeworkClockProvider)();
    final next = await AsyncValue.guard(
      () => _load(force: force, revision: revision),
    );
    if (revision != _revision) return false;
    state = next.hasValue || previous == null
        ? next
        : next.copyWithPrevious(AsyncData(previous));
    return true;
  }
}

class HomeworkStatusKey {
  const HomeworkStatusKey(
    this.userId,
    this.activityId, {
    this.closed = false,
    this.dueAt,
  });
  final int userId, activityId;
  final bool closed;
  final DateTime? dueAt;
  @override
  bool operator ==(Object other) =>
      other is HomeworkStatusKey &&
      other.userId == userId &&
      other.activityId == activityId &&
      other.closed == closed &&
      other.dueAt == dueAt;
  @override
  int get hashCode => Object.hash(userId, activityId, closed, dueAt);
}

final homeworkManualRefreshAtProvider = StateProvider.family<DateTime?, int>(
  (ref, uid) => null,
);

// Failed row checks must survive the row's autoDispose across tab switches.
final _submissionFailureAtProvider =
    StateProvider.family<DateTime?, ({int? owner, HomeworkStatusKey task})>(
      (ref, key) => null,
    );

/// Mounted lazily by visible student rows. No submission attachments or comments
/// are cached; only the normalized personal submission / grading state survives.
final homeworkSubmissionProvider = FutureProvider.autoDispose
    .family<HomeworkSubmissionState, HomeworkStatusKey>((ref, key) async {
      var alive = true;
      final token = CancelToken();
      Timer? timeout;
      ref.onDispose(() {
        alive = false;
        timeout?.cancel();
        token.cancel('作业状态已离开');
      });
      final scope = ref.watch(selectedRollcallAccountProvider);
      final owner = ref.watch(authControllerProvider).profile?.id;
      if ((scope ?? owner) != key.userId) throw StateError('作业身份已切换');
      final repository = ref.watch(homeworkRepositoryProvider);
      final requestedAt = ref.watch(
        homeworkManualRefreshAtProvider(key.userId),
      );
      final failureProvider = _submissionFailureAtProvider((
        owner: owner,
        task: key,
      ));
      final suffix = 'homework_submission_${key.userId}_${key.activityId}';
      final disk = await JsonDiskCache.readList(suffix);
      final cached = disk == null || disk.items.isEmpty
          ? null
          : HomeworkSubmissionState.fromJson(disk.items.first);
      final ttl = cached?.grading == HomeworkGrading.graded
          ? const Duration(hours: 24)
          : key.closed
          ? const Duration(hours: 2)
          : cached?.submission == HomeworkSubmission.submitted
          ? const Duration(minutes: 30)
          : CachePolicy.homeworkActiveFreshFor;
      final deadlinePassed =
          disk != null &&
          key.dueAt != null &&
          key.dueAt!.isAfter(disk.fetchedAt) &&
          !key.dueAt!.isAfter(DateTime.now());
      if (cached != null &&
          !deadlinePassed &&
          disk!.isFresh(ttl) &&
          (requestedAt == null || !disk.fetchedAt.isBefore(requestedAt))) {
        return cached;
      }
      final failedAt = ref.read(failureProvider);
      if (failedAt != null &&
          DateTime.now().difference(failedAt) <
              CachePolicy.homeworkStatusFailureBackoff &&
          (requestedAt == null || !requestedAt.isAfter(failedAt))) {
        if (cached != null) return cached;
        throw StateError('作业状态暂不可用，请稍后重试');
      }
      bool isCurrent() =>
          alive &&
          ref.read(selectedRollcallAccountProvider) == scope &&
          ref.read(authControllerProvider).profile?.id == owner;
      Future<HomeworkSubmissionState> refresh() async {
        try {
          if (!isCurrent()) throw StateError('作业身份已切换');
          timeout = Timer(
            const Duration(seconds: 30),
            () => token.cancel('作业状态查询超时'),
          );
          await Future.any<void>([
            prepareHomeworkSession(ref, scope),
            token.whenCancel.then<void>((error) => throw error),
          ]);
          if (!isCurrent()) throw StateError('作业身份已切换');
          final result = await FetchLog.run(
            event: 'homework.submission.refresh',
            trigger: requestedAt == null ? 'visible' : 'manual',
            fields: {'userId': key.userId, 'activityId': key.activityId},
            fetch: () => repository.fetchSubmission(
              activityId: key.activityId,
              studentId: key.userId,
              cancelToken: token,
            ),
          );
          if (!isCurrent()) throw StateError('作业身份已切换');
          ref.read(failureProvider.notifier).state = null;
          await JsonDiskCache.writeList(suffix, [result.toJson()]);
          if (isCurrent()) {
            ref.read(homeworkSubmissionRevisionProvider.notifier).state++;
          }
          return result;
        } catch (_) {
          if (isCurrent()) {
            ref.read(failureProvider.notifier).state = DateTime.now();
          }
          if (cached != null) return cached;
          rethrow;
        } finally {
          timeout?.cancel();
        }
      }

      if (cached == null) return refresh();
      // Restore the last known status before waiting for the network. The
      // deferred response may update only this still-mounted account scope.
      unawaited(
        Future<void>(() async {
          if (!isCurrent()) return;
          final result = await refresh();
          if (isCurrent()) ref.state = AsyncData(result);
        }),
      );
      return cached;
    });
