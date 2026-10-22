import 'package:xmu_rollcall/features/homework/homework_candidates.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/network/request_failure.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/core/logging/fetch_log.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_repository.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';

final currentTeachingCoursesProvider = FutureProvider<List<CatalogCourse>>((
  ref,
) async {
  final scope = ref.watch(selectedRollcallAccountProvider);
  if (!ref.watch(authControllerProvider).isSignedIn) return const [];
  final provider = ref.watch(scopedCourseCatalogProvider(scope));
  final catalog = await ref.watch(provider.future);
  return catalog?.teachingCourses ?? const [];
});

final homeworkRepositoryProvider = Provider<HomeworkRepository>((ref) {
  final scope = ref.watch(selectedRollcallAccountProvider);
  return HomeworkRepository(
    http: scope == null
        ? ref.watch(tronHttpClientProvider)
        : ref
              .watch(sessionClientRegistryProvider)
              .forKey(SessionKey.assist(scope)),
  );
});

Future<void> prepareHomeworkSession(Ref ref, int? scope) async {
  if (scope == null) return;
  final identity = ref
      .read(assistControllerProvider)
      .identities
      .firstWhere((a) => a.userId == scope);
  final service = await ref.read(assistServiceProvider.future);
  await service.ensureSession(identity);
}

final homeworkTodosProvider =
    AsyncNotifierProvider<HomeworkTodosNotifier, List<HomeworkItem>>(
      HomeworkTodosNotifier.new,
    );

class HomeworkTodosNotifier extends AsyncNotifier<List<HomeworkItem>> {
  static const ttl = Duration(minutes: 30);

  int? _boundUserId;
  int? _boundScope;
  int _revision = 0;
  DateTime? _fetchedAt;
  DateTime? get lastUpdatedAt => _fetchedAt;
  Future<void>? _inFlight;

  String? get _cacheSuffix {
    final id = _boundUserId;
    if (id == null || id == 0) return null;
    return 'homework_todos_$id';
  }

  @override
  Future<List<HomeworkItem>> build() async {
    final revision = ++_revision;
    ref.onDispose(() => _revision++);
    ref.keepAlive();
    final auth = ref.watch(authControllerProvider);
    final scope = ref.watch(selectedRollcallAccountProvider);
    _boundScope = scope;
    _fetchedAt = null;
    _inFlight = null;
    final profile = auth.profile;
    if (!auth.isSignedIn || profile == null || profile.id == 0) {
      _boundUserId = null;
      _fetchedAt = null;
      return const [];
    }
    _boundUserId = scope ?? profile.id;

    final suffix = _cacheSuffix;
    if (suffix != null) {
      final snap = await JsonDiskCache.readList(suffix);
      if (revision != _revision) return const [];
      if (snap != null) {
        _fetchedAt = snap.fetchedAt;
        return [for (final m in snap.items) HomeworkItem.fromJson(m)];
      }
    }
    return _fetchAndPersist(trigger: 'cold');
  }

  Future<void> ensureFresh({
    EnsureFreshReason reason = EnsureFreshReason.appear,
  }) async {
    final existing = _inFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final future = _ensureBody(reason);
    _inFlight = future;
    try {
      await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<void> _ensureBody(EnsureFreshReason reason) async {
    try {
      await future;
    } catch (_) {}
    final revision = _revision;
    final uid = _boundUserId;
    if (uid == null || uid == 0) return;

    final force = reason == EnsureFreshReason.pullToRefresh;
    if (!force && _fetchedAt != null) {
      final age = DateTime.now().difference(_fetchedAt!);
      if (!age.isNegative && age < ttl) return;
    }
    if (!force) {
      final suffix = 'homework_todos_$uid';
      final snap = await JsonDiskCache.readList(suffix);
      if (revision != _revision) return;
      if (snap != null && snap.isFresh(ttl)) {
        _fetchedAt = snap.fetchedAt;
        if (_boundUserId == uid) {
          state = AsyncData([
            for (final m in snap.items) HomeworkItem.fromJson(m),
          ]);
        }
        return;
      }
    }

    final previous = state.valueOrNull;
    final next = await AsyncValue.guard(
      () => _fetchAndPersist(trigger: reason.name),
    );
    if (_boundUserId != uid || revision != _revision) return;
    if (next.hasValue) {
      state = AsyncData(next.requireValue);
    } else {
      state = previous == null
          ? next
          : next.copyWithPrevious(AsyncData(previous));
      if (_boundScope == null && isSessionExpired(next.error)) {
        ref.read(authControllerProvider.notifier).expireSession();
      }
    }
  }

  Future<List<HomeworkItem>> _fetchAndPersist({required String trigger}) {
    final uid = _boundUserId;
    final revision = _revision;
    final scope = _boundScope;
    final repository = ref.read(homeworkRepositoryProvider);
    return FetchLog.run(
      event: 'homework.todos.refresh',
      trigger: trigger,
      fields: {'userId': uid, 'session': scope == null ? 'owner' : 'assist'},
      fetch: () async {
        await prepareHomeworkSession(ref, scope);
        if (revision != _revision) throw StateError('账号已切换');
        final detailed = await repository.fetchTodosDetailed();
        final data = detailed.items;
        if (_boundUserId != uid || revision != _revision) return detailed;
        _fetchedAt = DateTime.now();
        final suffix = _cacheSuffix;
        if (suffix != null) {
          await JsonDiskCache.writeList(suffix, [
            for (final e in data) e.toJson(),
          ], fetchedAt: _fetchedAt);
        }
        return detailed;
      },
      countOf: (d) => d.items.length,
      resultFields: (d) => d.diag,
      successLevel: (d) => d.diag['listKeyHit'] == null ? 'W' : 'I',
    ).then((d) => d.items);
  }

  Future<void> refresh() =>
      ensureFresh(reason: EnsureFreshReason.pullToRefresh);
}

final courseHomeworkProvider =
    AsyncNotifierProvider.family<
      CourseHomeworkNotifier,
      List<HomeworkItem>,
      int
    >(CourseHomeworkNotifier.new);

class CourseHomeworkNotifier
    extends FamilyAsyncNotifier<List<HomeworkItem>, int> {
  int? _boundUserId;
  int? _boundScope;
  int _revision = 0;
  DateTime? _fetchedAt;
  DateTime? get lastUpdatedAt => _fetchedAt;
  Future<void>? _inFlight;

  String? get _cacheSuffix {
    final id = _boundUserId;
    if (id == null || id == 0) return null;
    return 'course_homework_${id}_$arg';
  }

  @override
  Future<List<HomeworkItem>> build(int courseId) async {
    final revision = ++_revision;
    ref.onDispose(() => _revision++);
    ref.keepAlive();
    final auth = ref.watch(authControllerProvider);
    final scope = ref.watch(selectedRollcallAccountProvider);
    _boundScope = scope;
    _fetchedAt = null;
    _inFlight = null;
    final profile = auth.profile;
    if (!auth.isSignedIn || profile == null || profile.id == 0) {
      _boundUserId = null;
      return const [];
    }
    _boundUserId = scope ?? profile.id;

    final suffix = _cacheSuffix;
    if (suffix != null) {
      final snap = await JsonDiskCache.readList(suffix);
      if (revision != _revision) return const [];
      if (snap != null) {
        _fetchedAt = snap.fetchedAt;
        return [for (final m in snap.items) HomeworkItem.fromJson(m)];
      }
    }
    return _fetchAndPersist(trigger: 'cold');
  }

  Future<void> ensureFresh({
    EnsureFreshReason reason = EnsureFreshReason.appear,
  }) async {
    final existing = _inFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final future = _ensureBody(reason);
    _inFlight = future;
    try {
      await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<void> _ensureBody(EnsureFreshReason reason) async {
    try {
      await future;
    } catch (_) {}
    final revision = _revision;
    final uid = _boundUserId;
    if (uid == null || uid == 0) return;

    final force = reason == EnsureFreshReason.pullToRefresh;
    if (!force) {
      final disk = await JsonDiskCache.readList('course_homework_${uid}_$arg');
      final catalog = await CourseCatalogStore.read(uid);
      if (_revision != revision) return;
      CatalogCourse? course;
      for (final candidate in catalog?.courses ?? <CatalogCourse>[]) {
        if (candidate.id == '$arg') {
          course = candidate;
          break;
        }
      }
      if (homeworkRefreshReason(
            disk: disk,
            course: course,
            todos: ref.read(homeworkTodosProvider).valueOrNull ?? [],
            now: DateTime.now(),
          ) ==
          null) {
        return;
      }
    }

    final previous = state.valueOrNull;
    final next = await AsyncValue.guard(
      () => _fetchAndPersist(trigger: reason.name),
    );
    if (_boundUserId != uid || revision != _revision) return;
    if (next.hasValue) {
      state = AsyncData(next.requireValue);
    } else {
      state = previous == null
          ? next
          : next.copyWithPrevious(AsyncData(previous));
      if (_boundScope == null && isSessionExpired(next.error)) {
        ref.read(authControllerProvider.notifier).expireSession();
      }
    }
  }

  Future<List<HomeworkItem>> _fetchAndPersist({required String trigger}) {
    final uid = _boundUserId;
    final revision = _revision;
    final scope = _boundScope;
    final repository = ref.read(homeworkRepositoryProvider);
    return FetchLog.run(
      event: 'homework.course.refresh',
      trigger: trigger,
      fields: {
        'courseId': arg,
        'userId': uid,
        'session': scope == null ? 'owner' : 'assist',
      },
      fetch: () async {
        await prepareHomeworkSession(ref, scope);
        if (revision != _revision) throw StateError('账号已切换');
        final data = await repository.fetchCourseHomework(arg);
        if (_boundUserId != uid || revision != _revision) return data;
        _fetchedAt = DateTime.now();
        final suffix = _cacheSuffix;
        if (suffix != null) {
          await JsonDiskCache.writeList(suffix, [
            for (final e in data) e.toJson(),
          ], fetchedAt: _fetchedAt);
        }
        return data;
      },
    );
  }

  Future<void> refresh() =>
      ensureFresh(reason: EnsureFreshReason.pullToRefresh);
}

final homeworkDetailProvider = FutureProvider.autoDispose
    .family<HomeworkItem, HomeworkDetailKey>((ref, key) async {
      final seed = key.seed;
      final uid = ref.watch(authControllerProvider).profile?.id;
      final scope = ref.watch(selectedRollcallAccountProvider);
      final repository = ref.watch(homeworkRepositoryProvider);
      return FetchLog.run(
        event: 'homework.detail.fetch',
        trigger: 'user',
        fields: {
          'activityId': key.activityId,
          if (key.courseId != null) 'courseId': key.courseId,
        },
        fetch: () async {
          try {
            await prepareHomeworkSession(ref, scope);
            final remote = await repository.fetchDetail(
              activityId: key.activityId,
              courseId: key.courseId,
            );
            if (ref.read(authControllerProvider).profile?.id != uid ||
                ref.read(selectedRollcallAccountProvider) != scope) {
              return remote;
            }
            if (seed == null) return remote;
            return remote.copyWith(
              title: remote.title.isEmpty ? seed.title : remote.title,
              courseId: remote.courseId ?? seed.courseId,
              courseName: remote.courseName.isEmpty
                  ? seed.courseName
                  : remote.courseName,
              type: remote.type.isEmpty ? seed.type : remote.type,
              status: remote.status.isEmpty ? seed.status : remote.status,
              dueAt: remote.dueAt ?? seed.dueAt,
              description: remote.description.isEmpty
                  ? seed.description
                  : remote.description,
            );
          } catch (_) {
            if (seed != null) return seed;
            rethrow;
          }
        },
      );
    });

class HomeworkDetailKey {
  const HomeworkDetailKey({required this.activityId, this.courseId, this.seed});

  final int activityId;
  final int? courseId;
  final HomeworkItem? seed;

  @override
  bool operator ==(Object other) =>
      other is HomeworkDetailKey &&
      other.activityId == activityId &&
      other.courseId == courseId;

  @override
  int get hashCode => Object.hash(activityId, courseId);
}
