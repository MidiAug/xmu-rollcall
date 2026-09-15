import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    http: ref.watch(tronHttpClientProvider),
    store: ref.watch(secureStoreProvider),
  );
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(const AuthState(status: AuthStatus.unknown));

  final AuthRepository _repo;

  Future<void> bootstrap() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    final profile = await _repo.tryRestoreSession();
    if (profile != null) {
      state = AuthState(status: AuthStatus.signedIn, profile: profile);
    } else {
      state = const AuthState(status: AuthStatus.signedOut);
    }
  }

  Future<void> completeOAuthCode(String code) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final profile = await _repo.completeOAuthCode(code);
      state = AuthState(status: AuthStatus.signedIn, profile: profile);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.signedOut,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> importCookies(String cookieHeader) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final profile = await _repo.importCookiesAndProbe(cookieHeader);
      state = AuthState(status: AuthStatus.signedIn, profile: profile);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.signedOut,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
