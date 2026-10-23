import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository_providers.dart';

class AuthRepo extends Fake implements AuthRepository {}

class Auth extends AuthController {
  Auth() : super(AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
  void logout() => state = const AuthState(status: AuthStatus.signedOut);
}

class Repo extends Fake implements RollcallRepository {
  int calls = 0;
  final entered = Completer<void>();
  Completer<List<RollcallItem>>? pending;
  @override
  Future<List<RollcallItem>> fetchActive({
    CancelToken? cancelToken,
    String? opId,
  }) async {
    calls++;
    if (!entered.isCompleted) entered.complete();
    return pending?.future ?? Future.value([]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late Repo repo;
  late Auth auth;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'monitor_interval': 60,
      'monitor_jitter': 0.0,
    });
    repo = Repo();
    auth = Auth();
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        rollcallRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'concurrent starts share one operation and finish settings load first',
    () async {
      final ctrl = container.read(monitorControllerProvider.notifier);
      final first = ctrl.startAsync();
      final second = ctrl.startAsync();
      expect(identical(first, second), isTrue);
      expect(await first, StartMonitorResult.started);
      expect(container.read(monitorControllerProvider).config.enabled, isTrue);
      expect(
        container.read(monitorControllerProvider).config.intervalSeconds,
        60,
      );
      await repo.entered.future;
      expect(repo.calls, 1);
    },
  );

  test('stop during initialization cancels startup', () async {
    final ctrl = container.read(monitorControllerProvider.notifier);
    final start = ctrl.startAsync();
    ctrl.stop();
    expect(await start, StartMonitorResult.cancelled);
    expect(container.read(monitorControllerProvider).running, isFalse);
    expect(repo.calls, 0);
  });

  test(
    'account logout stops the task and rejects an in-flight response',
    () async {
      repo.pending = Completer<List<RollcallItem>>();
      final ctrl = container.read(monitorControllerProvider.notifier);
      await ctrl.startAsync();
      await repo.entered.future;
      auth.logout();
      expect(container.read(monitorControllerProvider).running, isFalse);
      repo.pending!.complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(monitorControllerProvider).lastPollAt, isNull);
      expect(container.read(monitorControllerProvider).nextPollAt, isNull);
    },
  );

  test('no session cannot start polling', () async {
    auth.logout();
    final ctrl = container.read(monitorControllerProvider.notifier);
    expect(await ctrl.startAsync(), StartMonitorResult.notSignedIn);
    expect(container.read(monitorControllerProvider).starting, isFalse);
    expect(repo.calls, 0);
  });
}
