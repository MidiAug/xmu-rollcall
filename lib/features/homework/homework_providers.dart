import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
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
  static const ttl = Duration(minutes: 10);

  DateTime? _fetchedAt;
  var _revalidateScheduled = false;

  String? get _cacheSuffix {
    final id = ref.read(authControllerProvider).profile?.id;
    if (id == null || id == 0) return null;
    return 'homework_todos_$id';
  }

  @override
  Future<List<HomeworkItem>> build() async {
    ref.keepAlive();
    final signedIn = ref.watch(authControllerProvider).isSignedIn;
    if (!signedIn) {
      _fetchedAt = null;
      _revalidateScheduled = false;
      return const [];
    }

    final suffix = _cacheSuffix;
    if (suffix != null) {
      final snap = await JsonDiskCache.readList(suffix);
      if (snap != null) {
        _fetchedAt = snap.fetchedAt;
        final items = [
          for (final m in snap.items) HomeworkItem.fromJson(m),
        ];
        if (!snap.isFresh(ttl)) {
          _scheduleRevalidate();
        }
        return items;
      }
    }
    return _fetchAndPersist();
  }

  void _scheduleRevalidate() {
    if (_revalidateScheduled) return;
    _revalidateScheduled = true;
    Future.microtask(() async {
      try {
        await _revalidate();
      } finally {
        _revalidateScheduled = false;
      }
    });
  }

  Future<void> _revalidate() async {
    final previous = state.valueOrNull;
    final next = await AsyncValue.guard(_fetchAndPersist);
    if (next.hasValue) {
      state = AsyncData(next.requireValue);
    } else if (previous == null) {
      state = next;
    }
  }

  Future<List<HomeworkItem>> _fetchAndPersist() async {
    final data = await ref.read(homeworkRepositoryProvider).fetchTodos();
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
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    final next = await AsyncValue.guard(_fetchAndPersist);
    if (next.hasValue) {
      state = AsyncData(next.requireValue);
    } else if (previous == null) {
      state = next;
    }
  }
}

final courseHomeworkProvider = AsyncNotifierProvider.family<
    CourseHomeworkNotifier, List<HomeworkItem>, int>(
  CourseHomeworkNotifier.new,
);

class CourseHomeworkNotifier
    extends FamilyAsyncNotifier<List<HomeworkItem>, int> {
  static const ttl = Duration(minutes: 10);

  DateTime? _fetchedAt;
  var _revalidateScheduled = false;

  String? get _cacheSuffix {
    final id = ref.read(authControllerProvider).profile?.id;
    if (id == null || id == 0) return null;
    return 'course_homework_${id}_$arg';
  }

  @override
  Future<List<HomeworkItem>> build(int courseId) async {
    ref.keepAlive();
    final suffix = _cacheSuffix;
    if (suffix != null) {
      final snap = await JsonDiskCache.readList(suffix);
      if (snap != null) {
        _fetchedAt = snap.fetchedAt;
        final items = [
          for (final m in snap.items) HomeworkItem.fromJson(m),
        ];
        if (!snap.isFresh(ttl)) {
          _scheduleRevalidate();
        }
        return items;
      }
    }
    return _fetchAndPersist();
  }

  void _scheduleRevalidate() {
    if (_revalidateScheduled) return;
    _revalidateScheduled = true;
    Future.microtask(() async {
      try {
        await _revalidate();
      } finally {
        _revalidateScheduled = false;
      }
    });
  }

  Future<void> _revalidate() async {
    final previous = state.valueOrNull;
    final next = await AsyncValue.guard(_fetchAndPersist);
    if (next.hasValue) {
      state = AsyncData(next.requireValue);
    } else if (previous == null) {
      state = next;
    }
  }

  Future<List<HomeworkItem>> _fetchAndPersist() async {
    final data =
        await ref.read(homeworkRepositoryProvider).fetchCourseHomework(arg);
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
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    final next = await AsyncValue.guard(_fetchAndPersist);
    if (next.hasValue) {
      state = AsyncData(next.requireValue);
    } else if (previous == null) {
      state = next;
    }
  }
}

final homeworkDetailProvider = FutureProvider.autoDispose
    .family<HomeworkItem, HomeworkDetailKey>((ref, key) async {
  final seed = key.seed;
  try {
    final remote = await ref.read(homeworkRepositoryProvider).fetchDetail(
          activityId: key.activityId,
          courseId: key.courseId,
        );
    if (seed == null) return remote;
    return remote.copyWith(
      title: remote.title.isEmpty ? seed.title : remote.title,
      courseId: remote.courseId ?? seed.courseId,
      courseName:
          remote.courseName.isEmpty ? seed.courseName : remote.courseName,
      type: remote.type.isEmpty ? seed.type : remote.type,
      status: remote.status.isEmpty ? seed.status : remote.status,
      dueAt: remote.dueAt ?? seed.dueAt,
      description:
          remote.description.isEmpty ? seed.description : remote.description,
    );
  } catch (_) {
    if (seed != null) return seed;
    rethrow;
  }
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
