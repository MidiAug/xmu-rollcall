import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';

final assistServiceProvider = FutureProvider<AssistService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return AssistService(
    store: ref.watch(secureStoreProvider),
    registry: ref.watch(sessionClientRegistryProvider),
    prefs: prefs,
  );
});

class AssistUiState {
  const AssistUiState({
    this.enabled = false,
    this.identities = const [],
    this.busy = false,
    this.errorMessage,
    this.ready = false,
  });

  final bool enabled;
  final List<AssistIdentity> identities;
  final bool busy;
  final String? errorMessage;
  final bool ready;

  AssistUiState copyWith({
    bool? enabled,
    List<AssistIdentity>? identities,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
    bool? ready,
  }) {
    return AssistUiState(
      enabled: enabled ?? this.enabled,
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
      final enabled = await svc.isEnabled();
      final identities = await svc.listIdentities();
      state = AssistUiState(
        enabled: enabled,
        identities: identities,
        ready: true,
      );
    } catch (e) {
      state = AssistUiState(ready: true, errorMessage: e.toString());
    }
  }

  Future<void> refresh() async {
    final svc = await _service();
    state = state.copyWith(
      enabled: await svc.isEnabled(),
      identities: await svc.listIdentities(),
      clearError: true,
      ready: true,
    );
  }

  Future<void> setEnabled(bool value) async {
    final svc = await _service();
    await svc.setEnabled(value);
    state = state.copyWith(enabled: value, clearError: true);
  }

  Future<String> exportOwner(String passphrase) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final auth = _ref.read(authControllerProvider);
      final profile = auth.profile;
      if (profile == null) {
        throw AssistException('请先登录主号再导出');
      }
      final svc = await _service();
      final sealed = await svc.exportOwnerPackage(
        passphrase: passphrase,
        profileId: profile.id,
        profileName: profile.name,
      );
      return sealed;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<AssistIdentity> importPackage({
    required String sealed,
    required String passphrase,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final ownerId = _ref.read(authControllerProvider).profile?.id;
      final svc = await _service();
      final identity = await svc.importPackage(
        sealed: sealed,
        passphrase: passphrase,
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
}
