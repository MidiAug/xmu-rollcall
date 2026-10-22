import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_repository.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';

class AuthRepo extends Fake implements AuthRepository {}

class Auth extends AuthController {
  Auth() : super(AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

RollcallItem row(int id) => RollcallItem(
  rollcallId: id,
  courseTitle: '测试',
  createdByName: '老师',
  type: RollcallType.number,
  status: 'on_call',
  rollcallStatus: 'on_call',
  isExpired: false,
  scored: false,
);

class Rollcalls extends Fake implements RollcallRepository {
  bool fail = false;
  bool answered = false;
  Completer<List<RollcallItem>>? enrichment;
  Completer<List<RollcallItem>>? initial;
  Completer<void>? initialEntered;
  @override
  Future<List<RollcallItem>> fetchActiveEnriched({
    CancelToken? cancelToken,
  }) async {
    if (fail) throw StateError('offline');
    if (initial != null) {
      initialEntered?.complete();
      return initial!.future;
    }
    return [
      answered
          ? RollcallItem.fromJson({
              'rollcall_id': 1,
              'is_number': true,
              'status': 'on_call_fine',
            })
          : row(1).copyWith(numberCode: '1234'),
    ];
  }

  @override
  Future<List<RollcallItem>> enrichActive(
    List<RollcallItem> items, {
    CancelToken? cancelToken,
  }) async => enrichment?.future ?? items;
}

class Homework extends Fake implements HomeworkRepository {
  bool fail = false;
  @override
  Future<HomeworkTodosFetch> fetchTodosDetailed() async {
    if (fail) throw StateError('offline');
    return const HomeworkTodosFetch(
      items: [HomeworkItem(id: 1, title: '作业')],
      diag: {'listKeyHit': 'todos'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late Rollcalls rollcalls;
  late Homework homework;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    rollcalls = Rollcalls();
    homework = Homework();
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => Auth()),
        rollcallRepositoryForProvider.overrideWith((ref, id) => rollcalls),
        homeworkRepositoryProvider.overrideWithValue(homework),
      ],
    );
  });
  tearDown(() => container.dispose());
  test(
    'signed refresh and cold reload retain the account cached number code',
    () async {
      await container.read(activeRollcallsProvider(null).future);
      rollcalls.answered = true;
      await container.read(activeRollcallsProvider(null).notifier).refresh();
      expect(
        container
            .read(activeRollcallsProvider(null))
            .requireValue
            .single
            .numberCode,
        '1234',
      );
      // Flush the ordered best-effort disk write before recreating the notifier.
      await Future<void>.delayed(Duration.zero);
      container.invalidate(activeRollcallsProvider(null));
      final restored = await container.read(
        activeRollcallsProvider(null).future,
      );
      expect(restored.single.isAnswered, isTrue);
      expect(restored.single.numberCode, '1234');
      final other = await container.read(activeRollcallsProvider(2).future);
      expect(other.single.numberCode, isNull);
    },
  );
  test('rollcall refresh failure retains rows and exposes error', () async {
    await container.read(activeRollcallsProvider(null).future);
    rollcalls.fail = true;
    await container.read(activeRollcallsProvider(null).notifier).refresh();
    final state = container.read(activeRollcallsProvider(null));
    expect(state.hasError, isTrue);
    expect(state.valueOrNull!.single.rollcallId, 1);
  });
  test(
    'empty monitor snapshot clears list and old enrichment cannot resurrect it',
    () async {
      await container.read(activeRollcallsProvider(null).future);
      final notifier = container.read(activeRollcallsProvider(null).notifier);
      rollcalls.enrichment = Completer<List<RollcallItem>>();
      notifier.applyMonitorItems([row(2)]);
      expect(
        container
            .read(activeRollcallsProvider(null))
            .requireValue
            .single
            .rollcallId,
        2,
      );
      notifier.applyMonitorItems([]);
      rollcalls.enrichment!.complete([row(2).copyWith(numberCode: '4567')]);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(activeRollcallsProvider(null)).requireValue,
        isEmpty,
      );
    },
  );
  test('homework refresh failure retains todos and exposes error', () async {
    await container.read(homeworkTodosProvider.future);
    homework.fail = true;
    await container.read(homeworkTodosProvider.notifier).refresh();
    final state = container.read(homeworkTodosProvider);
    expect(state.hasError, isTrue);
    expect(state.valueOrNull!.single.title, '作业');
  });

  test(
    'late initial request error cannot replace a newer monitor snapshot',
    () async {
      rollcalls.initial = Completer<List<RollcallItem>>();
      rollcalls.initialEntered = Completer<void>();
      final loading = container.read(activeRollcallsProvider(null).future);
      await rollcalls.initialEntered!.future;
      container
          .read(activeRollcallsProvider(null).notifier)
          .applyMonitorItems([]);
      rollcalls.initial!.completeError(StateError('old request'));
      await loading;
      await Future<void>.delayed(Duration.zero);
      final state = container.read(activeRollcallsProvider(null));
      expect(state.hasError, isFalse);
      expect(state.requireValue, isEmpty);
    },
  );
}
