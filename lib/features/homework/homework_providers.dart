import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
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

  List<HomeworkItem>? _cache;
  DateTime? _fetchedAt;

  @override
  Future<List<HomeworkItem>> build() async {
    ref.keepAlive();
    final signedIn = ref.watch(authControllerProvider).isSignedIn;
    if (!signedIn) {
      _cache = null;
      _fetchedAt = null;
      return const [];
    }
    return _load(force: false);
  }

  Future<List<HomeworkItem>> _load({required bool force}) async {
    if (!force &&
        _cache != null &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < ttl) {
      return _cache!;
    }
    final data = await ref.read(homeworkRepositoryProvider).fetchTodos();
    _cache = data;
    _fetchedAt = DateTime.now();
    return data;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(force: true));
  }
}

final courseHomeworkProvider = AsyncNotifierProvider.family<
    CourseHomeworkNotifier, List<HomeworkItem>, int>(
  CourseHomeworkNotifier.new,
);

class CourseHomeworkNotifier
    extends FamilyAsyncNotifier<List<HomeworkItem>, int> {
  static const ttl = Duration(minutes: 10);

  List<HomeworkItem>? _cache;
  DateTime? _fetchedAt;

  @override
  Future<List<HomeworkItem>> build(int courseId) async {
    ref.keepAlive();
    return _load(force: false);
  }

  Future<List<HomeworkItem>> _load({required bool force}) async {
    if (!force &&
        _cache != null &&
        _fetchedAt != null &&
        DateTime.now().difference(_fetchedAt!) < ttl) {
      return _cache!;
    }
    final data =
        await ref.read(homeworkRepositoryProvider).fetchCourseHomework(arg);
    _cache = data;
    _fetchedAt = DateTime.now();
    return data;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(force: true));
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
