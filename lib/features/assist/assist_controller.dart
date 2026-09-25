import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

final assistServiceProvider = FutureProvider<AssistService>((ref) async {
  final identity = ref.watch(deviceIdentityProvider);
  return AssistService(
    store: ref.watch(secureStoreProvider),
    registry: ref.watch(sessionClientRegistryProvider),
    courseCatalog: (client) async {
      final repo = RollcallRepository(http: client, identity: identity);
      return repo.fetchCourses();
    },
  );
});

class AssistUiState {
  const AssistUiState({
    this.identities = const [],
    this.busy = false,
    this.errorMessage,
    this.ready = false,
  });

  final List<AssistIdentity> identities;
  final bool busy;
  final String? errorMessage;
  final bool ready;

  AssistUiState copyWith({
    List<AssistIdentity>? identities,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    bool? ready,
  }) {
    return AssistUiState(
      identities: identities ?? this.identities,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      ready: ready ?? this.ready,
    );
  }
}

final assistControllerProvider =
    StateNotifierProvider<AssistController, AssistUiState>((ref) {
  return AssistController(ref);
});

class AssistController extends StateNotifier<AssistUiState> {
  AssistController(this._ref, {AssistUiState? initial, bool bootstrap = true})
      : super(initial ?? const AssistUiState()) {
    if (bootstrap) {
      _bootstrap();
    }
  }

  final Ref _ref;

  Future<AssistService> _service() => _ref.read(assistServiceProvider.future);

  Future<void> _bootstrap() async {
    try {
      final svc = await _service();
      final identities = await svc.listIdentities();
      state = AssistUiState(
        identities: identities,
        ready: true,
      );
    } catch (e) {
      state = AssistUiState(ready: true, errorMessage: e.toString());
    }
  }

  Future<void> refresh() async {
    final started = DateTime.now();
    AppLog.event('assist.roster.refresh');
    try {
      final svc = await _service();
      final identities = await svc.listIdentities();
      state = state.copyWith(
        identities: identities,
        clearError: true,
        ready: true,
      );
      AppLog.event(
        'assist.roster.refresh',
        fields: {
          'ok': true,
          'count': identities.length,
          'durationMs': DateTime.now().difference(started).inMilliseconds,
        },
      );
    } catch (e) {
      AppLog.event(
        'assist.roster.refresh',
        level: 'W',
        fields: {
          'ok': false,
          'errorType': e.runtimeType.toString(),
          'durationMs': DateTime.now().difference(started).inMilliseconds,
        },
      );
      rethrow;
    }
  }

  Future<String> exportOwner({
    required AssistExportKind kind,
    String? username,
    String? password,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final auth = _ref.read(authControllerProvider);
      final profile = auth.profile;
      if (profile == null) {
        throw AssistException('请先登录后再导出');
      }
      final deviceId = await _ref.read(deviceIdentityProvider).getId();
      final store = _ref.read(secureStoreProvider);
      final lastUser = await store.read(SecureStore.keyLastUsername);
      final savedPass = await store.read(SecureStore.keyOwnerPassword);
      final svc = await _service();
      return svc.exportOwnerPackage(
        kind: kind,
        profileId: profile.id,
        profileName: profile.name,
        deviceId: deviceId,
        username: username ?? lastUser,
        password: (password != null && password.isNotEmpty)
            ? password
            : savedPass,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<AssistIdentity> importToken(String token) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final ownerId = _ref.read(authControllerProvider).profile?.id;
      final svc = await _service();
      final identity = await svc.importToken(
        token,
        ownerUserId: ownerId,
      );
      await refresh();
      return identity;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<AssistIdentity> importPlainAccount({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final ownerId = _ref.read(authControllerProvider).profile?.id;
      final svc = await _service();
      final identity = await svc.importPlainAccount(
        username: username,
        password: password,
        ownerUserId: ownerId,
      );
      await refresh();
      return identity;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<void> removeIdentity(int userId) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final svc = await _service();
      await svc.removeIdentity(userId);
      await refresh();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<AssistIdentity> refreshSharedCourses(int userId) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final svc = await _service();
      final updated = await svc.syncSharedCourses(userId);
      await refresh();
      return updated;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(busy: false);
    }
  }
}
