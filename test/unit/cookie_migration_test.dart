import 'dart:async';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/session/cookie_codec.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

class FailingStore extends SecureStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('storage unavailable');
}

class Adapter implements HttpClientAdapter {
  final entered = Completer<void>();
  final response = Completer<ResponseBody>();
  int calls = 0;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    calls++;
    if (!entered.isCompleted) entered.complete();
    return response.future;
  }
}

void main() {
  final base = Uri.parse(TronEndpoints.baseUrl);
  test(
    'legacy cookie migration writes secure copy before deleting files',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'rollcall-cookie-test-',
      );
      try {
        final legacy = PersistCookieJar(storage: FileStorage(directory.path));
        await legacy.saveFromResponse(base, [Cookie('session', 'legacy')]);
        final store = SecureStore.memory();
        await migrateLegacyCookies(legacy, store, SessionKey.owner);
        expect(
          decodeCookies(
            (await store.read(SessionKey.owner.secureCookieKey))!,
          ).single.value,
          'legacy',
        );
        final reopened = PersistCookieJar(storage: FileStorage(directory.path));
        expect(await reopened.loadForRequest(base), isEmpty);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
  test('secure storage failure leaves legacy cookie intact', () async {
    final legacy = CookieJar();
    await legacy.saveFromResponse(base, [Cookie('session', 'legacy')]);
    await expectLater(
      migrateLegacyCookies(legacy, FailingStore(), SessionKey.owner),
      throwsStateError,
    );
    expect((await legacy.loadForRequest(base)).single.value, 'legacy');
  });
  test('existing secure session wins over stale legacy cookies', () async {
    final legacy = CookieJar();
    await legacy.saveFromResponse(base, [Cookie('session', 'old')]);
    final store = SecureStore.memory({
      SessionKey.owner.secureCookieKey: encodeCookies([
        Cookie('session', 'new'),
      ]),
    });
    await migrateLegacyCookies(legacy, store, SessionKey.owner);
    expect(
      decodeCookies(
        (await store.read(SessionKey.owner.secureCookieKey))!,
      ).single.value,
      'new',
    );
    expect(await legacy.loadForRequest(base), isEmpty);
  });
  test(
    'logout cancels queued and in-flight requests from old session',
    () async {
      final adapter = Adapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final client = TronHttpClient(
        store: SecureStore.memory(),
        cookieJar: CookieJar(),
        dio: dio,
        rateLimiter: RateLimiter(minInterval: Duration.zero, maxConcurrent: 1),
      );
      await Future.wait([client.init(), client.init()]);
      final first = client.getUri<dynamic>(base.resolve('/first'));
      final firstCheck = expectLater(
        first,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await adapter.entered.future;
      final second = client.getUri<dynamic>(base.resolve('/second'));
      final secondCheck = expectLater(
        second,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await client.clearSession();
      await Future.wait([firstCheck, secondCheck]);
      adapter.response.complete(ResponseBody.fromString('{}', 200));
      expect(adapter.calls, 1);
      dio.close();
    },
  );
}
