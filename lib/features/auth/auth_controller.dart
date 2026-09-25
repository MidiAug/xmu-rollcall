import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
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
    AppLog.event('auth.restore.start');
    final hasCookie = await _repo.hasStoredCookies();
    final profile = await _repo.tryRestoreSession();
    if (profile != null) {
      AppLog.event(
        'auth.restore.ok',
        fields: {'userId': profile.id},
      );
      state = AuthState(status: AuthStatus.signedIn, profile: profile);
    } else {
      AppLog.event(
        'auth.restore.fail',
        level: 'W',
        fields: {
          'errorType': 'restore_failed',
          'hasCookieBlob': hasCookie,
        },
      );
      state = const AuthState(status: AuthStatus.signedOut);
    }
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    // Keep signedOut while logging in so AdaptiveShell (and the login dialog
    // underlay) stay mounted. Dialog owns the busy UI via local state.
    state = state.copyWith(clearError: true);
    try {
      final profile = await _repo.signIn(
        username: username,
        password: password,
      );
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
    await JsonDiskCache.clearAll();
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
