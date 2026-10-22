import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';

class Repo extends Fake implements AuthRepository {
  Object? failure;
  UserProfile? result;
  UserProfile? cached;
  Completer<UserProfile?>? pending;
  @override
  Future<bool> hasStoredCookies() async => true;
  @override
  Future<UserProfile?> tryRestoreSession() async {
    if (failure != null) throw failure!;
    return pending?.future ?? result;
  }

  @override
  Future<UserProfile?> cachedProfile() async => cached;
  @override
  Future<void> signOut() async {}
}

void main() {
  test(
    'cached account is visible while network validation is pending',
    () async {
      final repo = Repo()
        ..cached = const UserProfile(id: 1, name: 'Test')
        ..pending = Completer<UserProfile?>();
      final auth = AuthController(repo);
      final pending = auth.bootstrap();
      await Future<void>.delayed(Duration.zero);
      expect(auth.state.isSignedIn, isTrue);
      repo.pending!.complete(null);
      await pending;
      expect(auth.state.status, AuthStatus.signedOut);
      auth.dispose();
    },
  );
  test(
    'network outage retains cached account and explicit retry message',
    () async {
      final repo = Repo()
        ..cached = const UserProfile(id: 1, name: 'Test')
        ..failure = DioException(
          requestOptions: RequestOptions(path: '/profile'),
          type: DioExceptionType.connectionError,
        );
      final auth = AuthController(repo);
      await auth.bootstrap();
      expect(auth.state.isSignedIn, isTrue);
      expect(auth.state.errorMessage, contains('网络'));
      repo.failure = null;
      repo.result = repo.cached;
      await auth.bootstrap();
      expect(auth.state.isSignedIn, isTrue);
      expect(auth.state.errorMessage, isNull);
      auth.dispose();
    },
  );
  test(
    'network outage without profile offers restore retry instead of logout',
    () async {
      final repo = Repo()..failure = StateError('offline');
      final auth = AuthController(repo);
      await auth.bootstrap();
      expect(auth.state.status, AuthStatus.restoreFailed);
      auth.dispose();
    },
  );
  test(
    'invalid restored session asks for login even with cached profile',
    () async {
      final repo = Repo()..cached = const UserProfile(id: 1, name: 'Test');
      final auth = AuthController(repo);
      await auth.bootstrap();
      expect(auth.state.status, AuthStatus.signedOut);
      auth.dispose();
    },
  );
  test('late restore cannot sign back in after logout', () async {
    final repo = Repo()..pending = Completer<UserProfile?>();
    final auth = AuthController(repo);
    final restore = auth.bootstrap();
    await Future<void>.delayed(Duration.zero);
    await auth.signOut();
    repo.pending!.complete(const UserProfile(id: 1, name: 'Test'));
    await restore;
    expect(auth.state.status, AuthStatus.signedOut);
    auth.dispose();
  });
}
