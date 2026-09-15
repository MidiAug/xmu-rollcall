import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_identity_store.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/session/session_credential_crypto.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:cookie_jar/cookie_jar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssistIdentityStore', () {
    test('upsert and remove persist metadata', () async {
      final store = SecureStore.memory();
      final roster = AssistIdentityStore(store);
      await roster.upsert(
        const AssistIdentity(
          userId: 9,
          displayName: '张三',
          importedAt: null,
        ),
      );
      expect((await roster.list()).single.displayName, '张三');
      await roster.remove(9);
      expect(await roster.list(), isEmpty);
    });
  });

  group('AssistService', () {
    late SecureStore store;
    late SessionClientRegistry registry;
    late AssistService service;
    late SessionCredentialCrypto crypto;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = SecureStore.memory();
      crypto = SessionCredentialCrypto(iterations: 1000);
      registry = SessionClientRegistry(
        store: store,
        createClient: ({
          required store,
          required sessionKey,
          required rateLimiter,
        }) {
          return TronHttpClient(
            store: store,
            sessionKey: sessionKey,
            rateLimiter: rateLimiter,
            cookieJar: CookieJar(),
          );
        },
      );
      service = AssistService(
        store: store,
        registry: registry,
        crypto: crypto,
        prefs: await SharedPreferences.getInstance(),
        probeProfile: (client) async {
          // Simulate successful probe using cookies already imported.
          final jar = client.cookieJar!;
          final cookies = await jar.loadForRequest(
            Uri.parse('https://lnt.xmu.edu.cn'),
          );
          String? sid;
          for (final c in cookies) {
            if (c.name == 'session') {
              sid = c.value;
              break;
            }
          }
          if (sid == null) throw AssistException('会话无效');
          return AssistProfileSnapshot(
            id: int.parse(sid),
            name: '导入用户$sid',
          );
        },
      );
    });

    test('assistEnabled defaults to false', () async {
      expect(await service.isEnabled(), isFalse);
    });

    test('export then import adds assist identity without touching owner',
        () async {
      final owner = registry.owner();
      await owner.init();
      await owner.importCookieHeader('session=1001');

      final sealed = await service.exportOwnerPackage(
        passphrase: 'secret',
        profileId: 1001,
        profileName: '本人',
        now: DateTime.utc(2026, 9, 15),
        ttl: const Duration(hours: 24),
      );

      await owner.clearSession();
      expect(await store.read(SecureStore.keySessionCookies), isNull);

      final identity = await service.importPackage(
        sealed: sealed,
        passphrase: 'secret',
        now: DateTime.utc(2026, 9, 15, 1),
      );
      expect(identity.userId, 1001);
      expect(identity.displayName, '导入用户1001');
      expect((await service.listIdentities()).map((e) => e.userId), [1001]);
      expect(await store.read(SecureStore.keySessionCookies), isNull);
      expect(
        await store.read(SessionKey.assist(1001).secureCookieKey),
        isNotNull,
      );
    });

    test('rejects importing owner self package', () async {
      final owner = registry.owner();
      await owner.init();
      await owner.importCookieHeader('session=1001');

      final sealed = await service.exportOwnerPackage(
        passphrase: 'secret',
        profileId: 1001,
        profileName: '本人',
        now: DateTime.utc(2026, 9, 15),
      );

      expect(
        () => service.importPackage(
          sealed: sealed,
          passphrase: 'secret',
          now: DateTime.utc(2026, 9, 15, 1),
          ownerUserId: 1001,
        ),
        throwsA(
          isA<AssistException>().having(
            (e) => e.message,
            'message',
            contains('自己的凭证'),
          ),
        ),
      );
    });

    test('rejects expired package', () async {
      final owner = registry.owner();
      await owner.init();
      await owner.importCookieHeader('session=5');
      final sealed = await service.exportOwnerPackage(
        passphrase: 'x',
        profileId: 5,
        profileName: 'A',
        now: DateTime.utc(2026, 1, 1),
        ttl: const Duration(hours: 1),
      );
      expect(
        () => service.importPackage(
          sealed: sealed,
          passphrase: 'x',
          now: DateTime.utc(2026, 1, 2),
        ),
        throwsA(isA<SessionCredentialException>()),
      );
    });

    test('removeIdentity clears jar and roster', () async {
      final owner = registry.owner();
      await owner.init();
      await owner.importCookieHeader('session=8');
      final sealed = await service.exportOwnerPackage(
        passphrase: 'p',
        profileId: 8,
        profileName: 'B',
        now: DateTime.utc(2026, 9, 15),
      );
      await service.importPackage(
        sealed: sealed,
        passphrase: 'p',
        now: DateTime.utc(2026, 9, 15),
      );
      await service.removeIdentity(8);
      expect(await service.listIdentities(), isEmpty);
      expect(await store.read(SessionKey.assist(8).secureCookieKey), isNull);
    });
  });
}
