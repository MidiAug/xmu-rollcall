import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_repository.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'A'),
    );
  }
}

class _Service extends Fake implements AssistService {
  @override
  Future<void> ensureSession(AssistIdentity identity) async {}
}

class _Repo extends Fake implements HomeworkRepository {
  _Repo(this.name);
  final String name;
  final entered = Completer<void>();
  Completer<HomeworkTodosFetch>? pending;
  int calls = 0;
  HomeworkItem get item => HomeworkItem(id: 9, title: name, courseId: 3);
  @override
  Future<HomeworkTodosFetch> fetchTodosDetailed() async {
    calls++;
    if (!entered.isCompleted) entered.complete();
    return pending?.future ?? HomeworkTodosFetch(items: [item], diag: const {});
  }

  @override
  Future<List<HomeworkItem>> fetchCourseHomework(int id) async => [item];
  @override
  Future<HomeworkItem> fetchDetail({
    required int activityId,
    int? courseId,
  }) async => item;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Repo a, b;
  ProviderContainer create() => ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => _Auth()),
      assistControllerProvider.overrideWith(
        (ref) => AssistController(
          ref,
          bootstrap: false,
          initial: const AssistUiState(
            ready: true,
            identities: [
              AssistIdentity(
                userId: 2,
                displayName: 'B',
                kind: AssistCredentialKind.session,
              ),
            ],
          ),
        ),
      ),
      assistServiceProvider.overrideWith((ref) async => _Service()),
      homeworkRepositoryProvider.overrideWith(
        (ref) => ref.watch(selectedRollcallAccountProvider) == null ? a : b,
      ),
    ],
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    a = _Repo('A');
    b = _Repo('B');
    container = create();
  });
  tearDown(() => container.dispose());
  void select(int? id) =>
      container.read(selectedRollcallAccountProvider.notifier).state = id;

  test(
    'todos, course homework and details follow selection and isolate caches',
    () async {
      expect(
        (await container.read(homeworkTodosProvider.future)).single.title,
        'A',
      );
      select(2);
      expect(
        (await container.read(homeworkTodosProvider.future)).single.title,
        'B',
      );
      expect(
        (await container.read(courseHomeworkProvider(3).future)).single.title,
        'B',
      );
      final detail = homeworkDetailProvider(
        const HomeworkDetailKey(activityId: 9, courseId: 3),
      );
      expect((await container.read(detail.future)).title, 'B');
      select(null);
      expect(
        (await container.read(homeworkTodosProvider.future)).single.title,
        'A',
      );
      expect(
        (await container.read(courseHomeworkProvider(3).future)).single.title,
        'A',
      );
      expect((await container.read(detail.future)).title, 'A');
      expect(
        (await JsonDiskCache.readList(
          'homework_todos_1',
        ))!.items.single['title'],
        'A',
      );
      expect(
        (await JsonDiskCache.readList(
          'homework_todos_2',
        ))!.items.single['title'],
        'B',
      );
    },
  );
  test(
    'late response from previous account cannot replace selected data',
    () async {
      a.pending = Completer<HomeworkTodosFetch>();
      final first = container.read(homeworkTodosProvider.future);
      await a.entered.future;
      select(2);
      expect(
        (await container.read(homeworkTodosProvider.future)).single.title,
        'B',
      );
      a.pending!.complete(HomeworkTodosFetch(items: [a.item], diag: const {}));
      await first;
      expect(
        container.read(homeworkTodosProvider).requireValue.single.title,
        'B',
      );
      expect(await JsonDiskCache.readList('homework_todos_1'), isNull);
    },
  );
  test(
    'selection persists across restart; manual selection wins over restore',
    () async {
      select(2);
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      container = create();
      container.read(selectedRollcallAccountProvider);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(selectedRollcallAccountProvider), 2);
      container.dispose();
      container = create();
      select(null);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(selectedRollcallAccountProvider), isNull);
    },
  );
}
