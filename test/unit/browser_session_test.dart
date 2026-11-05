import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/browser/browser_preferences.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';

void main() {
  test('website opening choice survives a new controller', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = WebsiteOpenModeController();
    await controller.ready;
    expect(controller.state, WebsiteOpenMode.inApp);
    await controller.set(WebsiteOpenMode.systemBrowser);
    final restored = WebsiteOpenModeController();
    await restored.ready;
    expect(restored.state, WebsiteOpenMode.systemBrowser);
    controller.dispose();
    restored.dispose();
  });

  test(
    'only unexpired IDS SSO cookies are reusable without changing scope',
    () {
      final now = DateTime(2026, 11, 5);
      final live = Cookie('CASTGC', 'test-sso')
        ..domain = 'ids.xmu.edu.cn'
        ..path = '/authserver'
        ..httpOnly = true
        ..secure = true
        ..expires = now.add(const Duration(hours: 1));
      final cookies = [
        live,
        Cookie('CASTGC', 'test-wrong-host')..domain = 'lnt.xmu.edu.cn',
        Cookie('happyVoyage', 'test-expired')
          ..expires = now.subtract(const Duration(seconds: 1)),
        Cookie('CASTGC', 'test-deleted')..maxAge = -1,
        Cookie('JSESSIONID', 'test-service-cookie')..domain = 'i.xmu.edu.cn',
        Cookie('session', 'test-tron-cookie')..domain = 'lnt.xmu.edu.cn',
        Cookie('CASTGC', 'test-parent-domain')..domain = '.xmu.edu.cn',
      ];
      expect(reusableIdsCookies(cookies, now: now), [same(live)]);
      expect(live.path, '/authserver');
      expect(live.secure && live.httpOnly, isTrue);
    },
  );

  test(
    'owner and assist bridge reads their actual jar and keeps browser profiles separate',
    () async {
      final store = SecureStore.memory();
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
      final ids = Uri.parse('https://ids.xmu.edu.cn/authserver/');
      for (final pair in [
        (SessionKey.owner, 'test-owner-sso'),
        (SessionKey.assist(22), 'test-assist-sso'),
      ]) {
        final client = registry.forKey(pair.$1);
        await client.init();
        await client.cookieJar!.saveFromResponse(ids, [
          Cookie('CASTGC', pair.$2)
            ..path = '/authserver'
            ..httpOnly = true
            ..secure = true,
        ]);
      }
      const owner = (ownerId: 11, userId: 11, assistId: null);
      const assist = (ownerId: 11, userId: 22, assistId: 22);
      final current = StateProvider<BrowserIdentity>((ref) => owner);
      final container = ProviderContainer(
        overrides: [
          browserIdentityProvider.overrideWith((ref) => ref.watch(current)),
          sessionClientRegistryProvider.overrideWithValue(registry),
        ],
      );
      addTearDown(container.dispose);
      expect(
        (await container.read(idsBrowserCookiesProvider.future)).single.value,
        'test-owner-sso',
      );
      container.read(current.notifier).state = assist;
      expect(
        (await container.read(idsBrowserCookiesProvider.future)).single.value,
        'test-assist-sso',
      );
      expect(browserProfileName(owner), isNot(browserProfileName(assist)));
      expect(
        browserProfileName(assist),
        isNot(browserProfileName((ownerId: 33, userId: 22, assistId: 22))),
      );
      container.read(current.notifier).state = (
        ownerId: null,
        userId: null,
        assistId: null,
      );
      expect(await container.read(idsBrowserCookiesProvider.future), isEmpty);
    },
  );
}
