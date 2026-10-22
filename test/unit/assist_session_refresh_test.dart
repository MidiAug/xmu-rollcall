import 'dart:async';
import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SecureStore store;
  late SessionClientRegistry registry;
  const identity = AssistIdentity(
    userId: 42,
    displayName: 'Demo',
    kind: AssistCredentialKind.account,
    deviceId: 'stable',
  );
  setUp(() {
    store = SecureStore.memory();
    registry = SessionClientRegistry(
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
  });
  test(
    'concurrent callers share one login; recent validation is reused until cookies change',
    () async {
      await store.write(
        AssistService.accountCredKey(42),
        jsonEncode({'username': 'demo', 'password': 'test-only'}),
      );
      var probes = 0;
      var logins = 0;
      final entered = Completer<void>();
      final release = Completer<void>();
      final service = AssistService(
        store: store,
        registry: registry,
        probeProfile: (_) async {
          probes++;
          if (probes == 1) {
            entered.complete();
            await release.future;
            throw DioException(
              requestOptions: RequestOptions(path: '/api/profile'),
              response: Response(
                requestOptions: RequestOptions(path: '/api/profile'),
                statusCode: 401,
              ),
            );
          }
          return const AssistProfileSnapshot(id: 42, name: 'Demo');
        },
        accountLogin:
            ({
              required username,
              required password,
              required targetClient,
            }) async {
              logins++;
              await targetClient.importCookieHeader('session=test-only');
              return const AssistProfileSnapshot(id: 42, name: 'Demo');
            },
      );
      final calls = List.generate(3, (_) => service.ensureSession(identity));
      await entered.future;
      expect(probes, 1);
      release.complete();
      await Future.wait(calls);
      expect(logins, 1);
      await service.ensureSession(identity);
      expect(probes, 1);
      final client = registry.forKey(SessionKey.assist(42));
      await client.importCookieHeader('session=replaced-test-only');
      await service.ensureSession(identity);
      expect(probes, 2);
    },
  );
  test(
    'network failure does not trigger a login and failed checks can retry',
    () async {
      var probes = 0;
      var logins = 0;
      final service = AssistService(
        store: store,
        registry: registry,
        probeProfile: (_) async {
          if (++probes == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/api/profile'),
              type: DioExceptionType.connectionTimeout,
            );
          }
          return const AssistProfileSnapshot(id: 42, name: 'Demo');
        },
        accountLogin:
            ({
              required username,
              required password,
              required targetClient,
            }) async {
              logins++;
              return const AssistProfileSnapshot(id: 42, name: 'Demo');
            },
      );
      await expectLater(
        service.ensureSession(identity),
        throwsA(isA<DioException>()),
      );
      expect(logins, 0);
      await service.ensureSession(identity);
      expect(probes, 2);
    },
  );
}
