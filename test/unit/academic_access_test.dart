import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_identity_store.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/grades/grade_providers.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter([this.wait]);
  final Future<void>? wait;
  final entered = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    entered.complete();
    await wait;
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'timetable and grade clients share admission, not cookies or HTTP lifetime',
    () async {
      final container = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(SecureStore.memory()),
          academicRateLimiterProvider.overrideWithValue(
            RateLimiter(
              minInterval: Duration.zero,
              maxConcurrent: 1,
              maxPerMinute: 100,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final timetable = container.read(academicSessionFactoryProvider)();
      final grades = container.read(gradeReaderProvider)().session;
      final release = Completer<void>();
      final first = _Adapter(release.future), second = _Adapter();
      timetable.dio.httpClientAdapter = first;
      grades.dio.httpClientAdapter = second;
      final request = timetable.hop(
        'GET',
        AcademicSession.jw.resolve('/timetable-test'),
      );
      await first.entered.future;
      final queued = grades.hop(
        'GET',
        AcademicSession.jw.resolve('/grade-test'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(second.entered.isCompleted, isFalse);
      release.complete();
      await Future.wait([request, queued]);
      expect(second.entered.isCompleted, isTrue);
      expect(timetable.jar, isNot(same(grades.jar)));
      timetable.dio.close();
      grades.dio.close();
    },
  );

  test(
    'one resolver preserves owner and imported credentials and revokes stale access',
    () async {
      final store = SecureStore.memory({
        SecureStore.keyUserId: '1',
        SecureStore.keyLastUsername: 'owner-test',
        SecureStore.keyOwnerPassword: 'owner-test-password',
        AssistService.accountCredKey(2): jsonEncode({
          'username': 'assist-test',
          'password': 'assist-test-password',
        }),
      });
      final roster = AssistIdentityStore(store);
      await roster.upsert(
        const AssistIdentity(
          userId: 2,
          displayName: 'Test',
          kind: AssistCredentialKind.account,
        ),
      );
      final registry = SessionClientRegistry(
        store: store,
        createClient:
            ({required store, required sessionKey, required rateLimiter}) =>
                TronHttpClient(
                  store: store,
                  sessionKey: sessionKey,
                  rateLimiter: rateLimiter,
                  cookieJar: CookieJar(),
                ),
      );
      final container = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(store),
          sessionClientRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);
      final resolve = container.read(academicIdentityResolverProvider);
      final owner = (await resolve(1))!;
      final assist = (await resolve(2))!;
      expect(owner.username, 'owner-test');
      expect(owner.password, 'owner-test-password');
      expect(assist.username, 'assist-test');
      expect(assist.password, 'assist-test-password');
      expect(await owner.isCurrent(), isTrue);
      expect(await assist.isCurrent(), isTrue);
      await roster.remove(2);
      expect(await assist.isCurrent(), isFalse);
      await registry.owner().clearSession();
      expect(await owner.isCurrent(), isFalse);
      expect(await resolve(2), isNull);
    },
  );
}
