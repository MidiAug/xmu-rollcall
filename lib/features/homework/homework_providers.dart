import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/core/logging/fetch_log.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_repository.dart';

final homeworkRepositoryProvider = Provider<HomeworkRepository>((ref) {
  return HomeworkRepository(http: ref.watch(tronHttpClientProvider));
});

final homeworkTodosProvider =
    AsyncNotifierProvider<HomeworkTodosNotifier, List<HomeworkItem>>(
  HomeworkTodosNotifier.new,
);

class HomeworkTodosNotifier extends AsyncNotifier<List<HomeworkItem>> {
  static const ttl = CachePolicy.enterSwrFreshFor;

  int? _boundUserId;
  DateTime? _fetchedAt;
  Future<void>? _inFlight;

  String? get _cacheSuffix {
    final id = _boundUserId;
    if (id == null || id == 0) return null;
    return 'homework_todos_$id';
  }

  @override
  Future<List<HomeworkItem>> build() async {
    ref.keepAlive();
    final auth = ref.watch(authControllerProvider);
    final profile = auth.profile;
    if (!auth.isSignedIn || profile == null || profile.id == 0) {
      _boundUserId = null;
      _fetchedAt = null;
      return const [];
    }
    _boundUserId = profile.id;

    final suffix = _cacheSuffix;
    if (suffix != null) {
      final snap = await JsonDiskCache.readList(suffix);
      if (snap != null) {
        _fetchedAt = snap.fetchedAt;
        return [
          for (final m in snap.items) HomeworkItem.fromJson(m),
        ];
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
    final uid = _boundUserId ?? ref.read(authControllerProvider).profile?.id;
    if (uid == null || uid == 0) return;

    final force = reason == EnsureFreshReason.pullToRefresh;
    if (!force && _fetchedAt != null) {
      final age = DateTime.now().difference(_fetchedAt!);
      if (!age.isNegative && age < ttl) return;
    }
    if (!force) {
      final suffix = 'homework_todos_$uid';
      final snap = await JsonDiskCache.readList(suffix);
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
    if (_boundUserId != uid) return;
    if (next.hasValue) {
      state = AsyncData(next.requireValue);
    } else if (previous == null) {
      state = next;
    }
  }

  Future<List<HomeworkItem>> _fetchAndPersist({required String trigger}) {
    final uid = _boundUserId;
    return FetchLog.run(
      event: 'homework.todos.refresh',
      trigger: trigger,
      fetch: () async {
        final data = await ref.read(homeworkRepositoryProvider).fetchTodos();
        if (_boundUserId != uid) return data;
        _fetchedAt = DateTime.now();
        final suffix = _cacheSuffix;
        if (suffix != null) {
          await JsonDiskCache.writeList(
            suffix,
            [for (final e in data) e.toJson()],
            fetchedAt: _fetchedAt,
          );
        }
        return data;
      },
    );
  }

  Future<void> refresh() =>
      ensureFresh(reason: EnsureFreshReason.pullToRefresh);
}

final courseHomeworkProvider = AsyncNotifierProvider.family<
    CourseHomeworkNotifier, List<HomeworkItem>, int>(
  CourseHomeworkNotifier.new,
);

class CourseHomeworkNotifier
    extends FamilyAsyncNotifier<List<HomeworkItem>, int> {
  static const ttl = CachePolicy.enterSwrFreshFor;

  int? _boundUserId;
  DateTime? _fetchedAt;
  Future<void>? _inFlight;

  String? get _cacheSuffix {
    final id = _boundUserId;
    if (id == null || id == 0) return null;
    return 'course_homework_${id}_$arg';
  }

  @override
  Future<List<HomeworkItem>> build(int courseId) async {
    ref.keepAlive();
    final auth = ref.watch(authControllerProvider);
    final profile = auth.profile;
    if (!auth.isSignedIn || profile == null || profile.id == 0) {
      _boundUserId = null;
      return const [];
    }
    _boundUserId = profile.id;

    final suffix = _cacheSuffix;
    if (suffix != null) {
      final snap = await JsonDiskCache.readList(suffix);
      if (snap != null) {
        _fetchedAt = snap.fetchedAt;
        return [
          for (final m in snap.items) HomeworkItem.fromJson(m),
        ];
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
    final uid = _boundUserId ?? ref.read(authControllerProvider).profile?.id;
    if (uid == null || uid == 0) return;

    final force = reason == EnsureFreshReason.pullToRefresh;
    if (!force && _fetchedAt != null) {
      final age = DateTime.now().difference(_fetchedAt!);
      if (!age.isNegative && age < ttl) return;
    }

    final previous = state.valueOrNull;
    final next = await AsyncValue.guard(
      () => _fetchAndPersist(trigger: reason.name),
    );
    if (_boundUserId != uid) return;
    if (next.hasValue) {
      state = AsyncData(next.requireValue);
    } else if (previous == null) {
      state = next;
    }
  }

  Future<List<HomeworkItem>> _fetchAndPersist({required String trigger}) {
    final uid = _boundUserId;
    return FetchLog.run(
      event: 'homework.course.refresh',
      trigger: trigger,
      fields: {'courseId': arg},
      fetch: () async {
        final data =
            await ref.read(homeworkRepositoryProvider).fetchCourseHomework(arg);
        if (_boundUserId != uid) return data;
        _fetchedAt = DateTime.now();
        final suffix = _cacheSuffix;
        if (suffix != null) {
          await JsonDiskCache.writeList(
            suffix,
            [for (final e in data) e.toJson()],
            fetchedAt: _fetchedAt,
          );
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
  return FetchLog.run(
    event: 'homework.detail.fetch',
    trigger: 'user',
    fields: {
      'activityId': key.activityId,
      if (key.courseId != null) 'courseId': key.courseId,
    },
    fetch: () async {
      try {
        final remote = await ref.read(homeworkRepositoryProvider).fetchDetail(
              activityId: key.activityId,
              courseId: key.courseId,
            );
        if (ref.read(authControllerProvider).profile?.id != uid) {
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
  const HomeworkDetailKey({
    required this.activityId,
    this.courseId,
    this.seed,
  });

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
