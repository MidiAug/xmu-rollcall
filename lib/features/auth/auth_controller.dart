import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    http: ref.watch(tronHttpClientProvider),
    store: ref.watch(secureStoreProvider),
  );
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo, {this.beforeSignOut})
    : super(const AuthState(status: AuthStatus.unknown));

  final AuthRepository _repo;
  final Future<void> Function()? beforeSignOut;
  int _generation = 0;

  Future<void> bootstrap() async {
    final generation = ++_generation;
    bool current() => mounted && generation == _generation;
    state = state.copyWith(
      status: state.isSignedIn ? AuthStatus.signedIn : AuthStatus.loading,
      clearError: true,
    );
    AppLog.event('auth.restore.start');
    final watch = Stopwatch()..start();
    UserProfile? cached;
    try {
      final hasCookie = await _repo.hasStoredCookies();
      if (!current()) return;
      if (!hasCookie) {
        state = const AuthState(status: AuthStatus.signedOut);
        return;
      }
      try {
        cached = await _repo.cachedProfile();
      } catch (error) {
        AppLog.event(
          'auth.cache.read_error',
          level: 'W',
          fields: {'errorType': error.runtimeType.toString()},
        );
      }
      if (!current()) return;
      if (cached != null) {
        state = AuthState(status: AuthStatus.signedIn, profile: cached);
        AppLog.event(
          'auth.restore.cached',
          fields: {'elapsedMs': watch.elapsedMilliseconds},
        );
      }
      final profile = await _repo.tryRestoreSession();
      if (!current()) return;
      if (profile != null) {
        AppLog.event(
          'auth.restore.ok',
          fields: {
            'userId': profile.id,
            'elapsedMs': watch.elapsedMilliseconds,
          },
        );
        state = AuthState(status: AuthStatus.signedIn, profile: profile);
      } else {
        AppLog.event(
          'auth.restore.fail',
          level: 'W',
          fields: {'errorType': 'restore_failed', 'hasCookieBlob': hasCookie},
        );
        state = const AuthState(status: AuthStatus.signedOut);
      }
    } catch (error, stack) {
      AppLog.logAppError(
        error: error,
        stackTrace: stack,
        source: 'auth_restore',
      );
      try {
        cached ??= await _repo.cachedProfile();
      } catch (_) {}
      if (!current()) return;
      state = AuthState(
        status: cached == null ? AuthStatus.restoreFailed : AuthStatus.signedIn,
        profile: cached,
        errorMessage: '暂时无法验证登录，请检查网络后重试',
      );
    }
  }

  void expireSession() {
    if (!state.isSignedIn) return;
    _generation++;
    state = const AuthState(
      status: AuthStatus.signedOut,
      errorMessage: '登录已失效，请重新登录',
    );
  }

  Future<void> signIn({
    required String username,
    required String password,
    bool rememberPassword = false,
  }) async {
    final generation = ++_generation;
    // Keep signedOut while logging in so AdaptiveShell (and the login dialog
    // underlay) stay mounted. Dialog owns the busy UI via local state.
    state = state.copyWith(clearError: true);
    try {
      final profile = await _repo.signIn(
        username: username,
        password: password,
        rememberPassword: rememberPassword,
      );
      if (!mounted || generation != _generation) return;
      state = AuthState(status: AuthStatus.signedIn, profile: profile);
    } catch (e) {
      if (!mounted || generation != _generation) rethrow;
      state = AuthState(
        status: AuthStatus.signedOut,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    _generation++;
    await beforeSignOut?.call();
    await _repo.signOut();
    // Disk mirrors kept (R-35 S2); memory cleared via [sessionLifecycleProvider].
    state = const AuthState(status: AuthStatus.signedOut);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(
      ref.watch(authRepositoryProvider),
      beforeSignOut: () => ref
          .read(monitorControllerProvider.notifier)
          .stopAsync(reason: 'sign_out'),
    );
  },
);
