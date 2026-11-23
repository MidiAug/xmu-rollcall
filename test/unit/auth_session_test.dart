import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/auth_session.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/schedule/academic_sync.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';

class _Repository extends Fake implements AuthRepository {
  void Function()? onSignOut;
  Future<void> Function()? signOutHandler;
  Future<UserProfile> Function()? signInHandler;
  static const profile = UserProfile(id: 1, name: 'Test');

  @override
  Future<bool> hasStoredCookies() async => true;
  @override
  Future<UserProfile?> cachedProfile() async => profile;
  @override
  Future<UserProfile?> tryRestoreSession() async => profile;
  @override
  Future<UserProfile> signIn({
    required String username,
    required String password,
    bool rememberPassword = false,
  }) async => signInHandler != null ? await signInHandler!() : profile;
  @override
  Future<void> signOut() async {
    onSignOut?.call();
    if (signOutHandler != null) await signOutHandler!();
  }
}

class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter(this.onFetch);
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) => onFetch(options);
}

class _AcademicSync extends AcademicSync {
  _AcademicSync(super.store);
  final calls = <({int uid, bool force, String? username, String? password})>[];
  Completer<void>? pending;

  @override
  Future<void> sync(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    bool force = false,
  }) async {
    calls.add((uid: uid, force: force, username: username, password: password));
    await pending?.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Repository repo;
  late _AcademicSync sync;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final store = SecureStore.memory();
    repo = _Repository();
    sync = _AcademicSync(store);
    container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(repo),
        academicSyncProvider.overrideWithValue(sync),
        authControllerProvider.overrideWith(createAppAuthController),
        assistControllerProvider.overrideWith(
          (ref) => AssistController(
            ref,
            bootstrap: false,
            initial: const AssistUiState(ready: true),
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'app wiring syncs restored and new sessions, stops before logout',
    () async {
      final auth = container.read(authControllerProvider.notifier);
      await auth.bootstrap();
      expect(sync.calls.single, (
        uid: 1,
        force: false,
        username: null,
        password: null,
      ));

      await auth.signIn(username: 'test-user', password: 'test-password');
      await Future<void>.delayed(Duration.zero);
      expect(sync.calls.last, (
        uid: 1,
        force: false,
        username: 'test-user',
        password: 'test-password',
      ));
      expect(container.read(academicRevisionProvider), 1);

      final monitor = container.read(monitorControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      monitor.debugArmRunning();
      expect(container.read(monitorControllerProvider).running, isTrue);
      repo.onSignOut = () {
        expect(container.read(monitorControllerProvider).running, isFalse);
      };
      await auth.signOut();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
    },
  );

  test(
    'a sync finishing after session expiry does not signal a logged-in refresh',
    () async {
      sync.pending = Completer<void>();
      final auth = container.read(authControllerProvider.notifier);
      await auth.signIn(username: 'test-user', password: 'test-password');
      auth.expireSession();
      sync.pending!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(academicRevisionProvider), 0);
    },
  );

  test(
    'assist owner sharing uses persisted catalog without loading its provider',
    () async {
      await container.read(authControllerProvider.notifier).bootstrap();
      await CourseCatalogStore.write(
        1,
        CourseCatalogSnapshot(
          fetchedAt: DateTime(2026, 10, 29),
          courses: const [CatalogCourse(id: '10', title: 'Test course')],
        ),
      );
      final service = await container.read(assistServiceProvider.future);
      final courses = await service.courseCatalog!(
        container.read(sessionClientRegistryProvider).owner(),
      );
      expect(courses.single.id, '10');
      expect(courses.single.title, 'Test course');
    },
  );

  test(
    'signOut continues cleanup when beforeSignOut or repo.signOut throws and ends signedOut',
    () async {
      var repoSignOutCalls = 0;
      final testRepo = _Repository()
        ..signOutHandler = () async {
          repoSignOutCalls++;
          throw StateError('repo signOut failed');
        };
      final auth = AuthController(
        testRepo,
        beforeSignOut: () async => throw StateError('beforeSignOut failed'),
      );
      await auth.signIn(username: 'test-user', password: 'test-password');
      expect(auth.state.status, AuthStatus.signedIn);

      await auth.signOut();
      expect(repoSignOutCalls, 1);
      expect(auth.state.status, AuthStatus.signedOut);
      auth.dispose();
    },
  );

  test(
    'signIn completing during pending signOut is not overwritten by old signOut',
    () async {
      final signOutGate = Completer<void>();
      final testRepo = _Repository();
      final auth = AuthController(
        testRepo,
        beforeSignOut: () => signOutGate.future,
      );
      await auth.signIn(username: 'test-user', password: 'test-password');
      expect(auth.state.status, AuthStatus.signedIn);

      final pendingSignOut = auth.signOut();
      await Future<void>.delayed(Duration.zero);

      await auth.signIn(username: 'test-user', password: 'test-password');
      expect(auth.state.status, AuthStatus.signedIn);

      signOutGate.complete();
      await pendingSignOut;
      expect(auth.state.status, AuthStatus.signedIn);
      auth.dispose();
    },
  );

  test(
    'signIn maps DioException with URL to friendly Chinese message without leaking URL or Dio',
    () async {
      final secretUrl = 'https://ids.xmu.edu.cn/authserver/login?ticket=st-1';
      Object nextError = DioException(
        requestOptions: RequestOptions(path: secretUrl),
        type: DioExceptionType.connectionTimeout,
      );
      final dio = Dio()
        ..httpClientAdapter = _FailingAdapter((options) async {
          if (nextError case final DioException err) {
            throw DioException(
              requestOptions: options.copyWith(path: secretUrl),
              type: err.type,
              response: err.response == null
                  ? null
                  : Response(
                      requestOptions: options.copyWith(path: secretUrl),
                      statusCode: err.response!.statusCode,
                    ),
            );
          }
          throw nextError;
        });
      final http = TronHttpClient(
        store: SecureStore.memory(),
        dio: dio,
        cookieJar: CookieJar(),
        rateLimiter: RateLimiter(minInterval: Duration.zero),
      );
      final authRepo = AuthRepository(http: http, store: SecureStore.memory());

      final cases = <({Object error, String expected})>[
        (
          error: DioException(
            requestOptions: RequestOptions(path: secretUrl),
            type: DioExceptionType.connectionTimeout,
          ),
          expected: '超时',
        ),
        (
          error: DioException(
            requestOptions: RequestOptions(path: secretUrl),
            type: DioExceptionType.connectionError,
          ),
          expected: '网络连接失败',
        ),
        (
          error: DioException(
            requestOptions: RequestOptions(path: secretUrl),
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: RequestOptions(path: secretUrl),
              statusCode: 429,
            ),
          ),
          expected: '频繁',
        ),
        (
          error: DioException(
            requestOptions: RequestOptions(path: secretUrl),
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: RequestOptions(path: secretUrl),
              statusCode: 503,
            ),
          ),
          expected: '暂时不可用',
        ),
        (
          error: StateError('secret internal $secretUrl'),
          expected: '登录失败',
        ),
      ];

      for (final c in cases) {
        nextError = c.error;
        await expectLater(
          authRepo.signIn(username: 'test-user', password: 'test-password'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains(c.expected),
                isNot(contains('ids.xmu.edu.cn')),
                isNot(contains('Dio')),
              ),
            ),
          ),
        );
      }

      final rawDioRepo = _Repository()
        ..signInHandler = () async => throw DioException(
          requestOptions: RequestOptions(path: secretUrl),
          type: DioExceptionType.connectionError,
        );
      final auth = AuthController(rawDioRepo);
      await expectLater(
        auth.signIn(username: 'test-user', password: 'test-password'),
        throwsA(isA<DioException>()),
      );
      expect(auth.state.status, AuthStatus.signedOut);
      expect(auth.state.errorMessage, '登录失败，请检查网络后重试');
      expect(auth.state.errorMessage, isNot(contains('ids.xmu.edu.cn')));
      expect(auth.state.errorMessage, isNot(contains('Dio')));
      auth.dispose();
      dio.close();
    },
  );
}
