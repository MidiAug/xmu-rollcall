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
          kind: AssistCredentialKind.session,
          importedAt: null,
        ),
      );
      expect((await roster.list()).single.displayName, '张三');
      expect((await roster.list()).single.kind, AssistCredentialKind.session);
      await roster.remove(9);
      expect(await roster.list(), isEmpty);
    });
  });

  group('AssistService', () {
    late SecureStore store;
    late SessionClientRegistry registry;
    late AssistService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = SecureStore.memory();
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
        codec: AssistTokenCodec(),
        prefs: await SharedPreferences.getInstance(),
        courseCatalog: (client) async {
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
          if (sid == null || sid.isEmpty) return const [];
          if (sid == '1001' || sid == '8') {
            return const [
              AssistSharedCourse(id: '501', title: '高等数学A'),
              AssistSharedCourse(id: '502', title: '大学英语'),
            ];
          }
          if (sid == '2002') {
            return const [
              AssistSharedCourse(id: '501', title: '高等数学A'),
            ];
          }
          return const [];
        },
        probeProfile: (client) async {
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
        accountLogin: ({
          required username,
          required password,
          required targetClient,
        }) async {
          await targetClient.init();
          await targetClient.importCookieHeader('session=2002');
          return const AssistProfileSnapshot(id: 2002, name: '账密用户');
        },
      );
    });

    test('assistEnabled defaults to false', () async {
      expect(await service.isEnabled(), isFalse);
    });

    test('export session then import without passphrase', () async {
      final owner = registry.owner();
      await owner.init();
      await owner.importCookieHeader('session=1001');

      final sealed = await service.exportOwnerPackage(
        kind: AssistExportKind.session,
        profileId: 1001,
        profileName: '本人',
        deviceId: 'owner-dev',
      );
      expect(sealed.startsWith('xmu2.'), isTrue);

      await owner.clearSession();
      expect(await store.read(SecureStore.keySessionCookies), isNull);

      final identity = await service.importToken(sealed);
      expect(identity.userId, 1001);
      expect(identity.kind, AssistCredentialKind.session);
      expect(identity.deviceId, 'owner-dev');
      expect(identity.displayName, '导入用户1001');
      // Owner jar was cleared above → sync cannot intersect; shared stays empty.
      expect(identity.sharedCourses, isEmpty);
      expect((await service.listIdentities()).map((e) => e.userId), [1001]);
      expect(await store.read(SecureStore.keySessionCookies), isNull);
      expect(
        await store.read(SessionKey.assist(1001).secureCookieKey),
        isNotNull,
      );

      // Re-login owner then refresh shared courses.
      await owner.importCookieHeader('session=1001');
      final synced = await service.syncSharedCourses(1001);
      expect(synced.sharedCourses.map((e) => e.id), ['501', '502']);
      expect(synced.sharedCoursesSyncedAt, isNotNull);
    });

    test('rejects importing owner self package', () async {
      final owner = registry.owner();
      await owner.init();
      await owner.importCookieHeader('session=1001');

      final sealed = await service.exportOwnerPackage(
        kind: AssistExportKind.session,
        profileId: 1001,
        profileName: '本人',
        deviceId: 'd',
      );

      expect(
        () => service.importToken(sealed, ownerUserId: 1001),
        throwsA(
          isA<AssistException>().having(
            (e) => e.message,
            'message',
            contains('自己的凭证'),
          ),
        ),
      );
    });

    test('export account package and import stores creds', () async {
      final sealed = await service.exportOwnerPackage(
        kind: AssistExportKind.account,
        profileId: 1,
        profileName: '本人',
        deviceId: 'acc-dev',
        username: '318xxx',
        password: 'pw',
      );
      final identity = await service.importToken(sealed);
      expect(identity.userId, 2002);
      expect(identity.kind, AssistCredentialKind.account);
      expect(identity.deviceId, 'acc-dev');
      expect(
        await store.read(AssistService.accountCredKey(2002)),
        isNotNull,
      );
    });

    test('import plain account', () async {
      final identity = await service.importPlainAccount(
        username: '318yyy',
        password: 'pw',
        deviceId: 'plain-dev',
      );
      expect(identity.kind, AssistCredentialKind.account);
      expect(identity.deviceId, 'plain-dev');
      expect(identity.userId, 2002);
    });

    test('removeIdentity clears jar roster and account creds', () async {
      final owner = registry.owner();
      await owner.init();
      await owner.importCookieHeader('session=8');
      final sealed = await service.exportOwnerPackage(
        kind: AssistExportKind.session,
        profileId: 8,
        profileName: 'B',
        deviceId: 'd',
      );
      await service.importToken(sealed);
      await service.removeIdentity(8);
      expect(await service.listIdentities(), isEmpty);
      expect(await store.read(SessionKey.assist(8).secureCookieKey), isNull);
    });
  });
}
