import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

void main() {
  group('session cookie isolation', () {
    test('owner and assist jars do not share cookies', () async {
      final store = SecureStore.memory();
      final ownerJar = CookieJar();
      final assistJar = CookieJar();
      final owner = TronHttpClient(
        store: store,
        sessionKey: SessionKey.owner,
        cookieJar: ownerJar,
      );
      final assist = TronHttpClient(
        store: store,
        sessionKey: SessionKey.assist(42),
        cookieJar: assistJar,
      );

      await owner.init();
      await assist.init();
      await owner.importCookieHeader('owner_tok=AAA');
      await assist.importCookieHeader('assist_tok=BBB');

      final base = Uri.parse(TronEndpoints.baseUrl);
      final ownerCookies = await ownerJar.loadForRequest(base);
      final assistCookies = await assistJar.loadForRequest(base);

      expect(ownerCookies.map((c) => c.name), contains('owner_tok'));
      expect(ownerCookies.map((c) => c.name), isNot(contains('assist_tok')));
      expect(assistCookies.map((c) => c.name), contains('assist_tok'));
      expect(assistCookies.map((c) => c.name), isNot(contains('owner_tok')));
    });

    test('clearing owner session leaves assist cookies and secure blob', () async {
      final store = SecureStore.memory();
      final owner = TronHttpClient(
        store: store,
        sessionKey: SessionKey.owner,
        cookieJar: CookieJar(),
      );
      final assistKey = SessionKey.assist(99);
      final assist = TronHttpClient(
        store: store,
        sessionKey: assistKey,
        cookieJar: CookieJar(),
      );

      await owner.init();
      await assist.init();
      await owner.importCookieHeader('o=1');
      await assist.importCookieHeader('a=2');
      await store.write(SecureStore.keyUserId, '1');
      await store.write(SecureStore.keyUserDisplayName, 'Owner');

      await owner.clearSession();

      expect(await store.read(SecureStore.keySessionCookies), isNull);
      expect(await store.read(SecureStore.keyUserId), isNull);
      expect(await store.read(assistKey.secureCookieKey), isNotNull);
      expect(await assist.cookieJar!.loadForRequest(Uri.parse(TronEndpoints.baseUrl)),
          isNotEmpty);
    });

    test('registry returns distinct clients that share rate limiter identity', () {
      final store = SecureStore.memory();
      final registry = SessionClientRegistry(
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

      final a = registry.forKey(SessionKey.owner);
      final b = registry.forKey(SessionKey.owner);
      final c = registry.forKey(SessionKey.assist(1));
      expect(identical(a, b), isTrue);
      expect(identical(a, c), isFalse);
    });

    test('registry disposeAssist clears that session only', () async {
      final store = SecureStore.memory();
      final registry = SessionClientRegistry(
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

      final owner = registry.owner();
      final assist = registry.forKey(SessionKey.assist(7));
      await owner.init();
      await assist.init();
      await owner.importCookieHeader('o=1');
      await assist.importCookieHeader('a=2');

      await registry.disposeAssist(7);

      expect(await store.read(SessionKey.assist(7).secureCookieKey), isNull);
      expect(await store.read(SecureStore.keySessionCookies), isNotNull);

      final again = registry.forKey(SessionKey.assist(7));
      expect(identical(again, assist), isFalse);
    });
    test('export/import cookies json round-trips on assist client', () async {
      final store = SecureStore.memory();
      final client = TronHttpClient(
        store: store,
        sessionKey: SessionKey.assist(3),
        cookieJar: CookieJar(),
      );
      await client.init();
      await client.importCookieHeader('sid=xyz');
      final exported = await client.exportCookiesJson();
      expect(exported, isNotNull);

      final other = TronHttpClient(
        store: SecureStore.memory(),
        sessionKey: SessionKey.assist(3),
        cookieJar: CookieJar(),
      );
      await other.importCookiesJson(exported!);
      final loaded =
          await other.cookieJar!.loadForRequest(Uri.parse(TronEndpoints.baseUrl));
      expect(loaded.map((c) => '${c.name}=${c.value}'), contains('sid=xyz'));
    });
  });
}
