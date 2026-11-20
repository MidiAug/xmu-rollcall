import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/cookie_codec.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

class _Store extends SecureStore {
  _Store([super.seed]) : super.memory();
  int reads = 0, writes = 0;
  bool fail = false;
  Completer<void>? writing, release;
  @override
  Future<String?> read(String key) {
    reads++;
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    if (fail) {
      fail = false;
      throw StateError('synthetic storage failure');
    }
    writing?.complete();
    await release?.future;
    await super.write(key, value);
  }
}

class _Adapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{}', 200);
}

TronHttpClient _client(_Store store) => TronHttpClient(
  store: store,
  cookieJar: CookieJar(),
  dio: Dio()..httpClientAdapter = _Adapter(),
  rateLimiter: RateLimiter(minInterval: Duration.zero, maxPerMinute: 10000),
);

void main() {
  test(
    'responses reuse persisted cookies without further secure reads or writes',
    () async {
      final store = _Store();
      final http = _client(store);
      await http.importCookieHeader('sample=value');
      final reads = store.reads, writes = store.writes;
      await Future.wait(
        List.generate(
          20,
          (_) => http.getUri<dynamic>(
            Uri.parse('https://lnt.xmu.edu.cn/api/test'),
          ),
        ),
      );
      expect(store.reads, reads);
      expect(store.writes, writes);
    },
  );
  test('restored cookies do not need to be written again', () async {
    final encoded = encodeCookies([
      Cookie('sample', 'value')
        ..domain = 'lnt.xmu.edu.cn'
        ..path = '/',
    ]);
    final store = _Store({SecureStore.keySessionCookies: encoded});
    final http = _client(store);
    await http.init();
    await http.persistCookies();
    expect(store.reads, 1);
    expect(store.writes, 0);
  });
  test(
    'failed write does not advance deduplication or poison later saves',
    () async {
      final store = _Store()..fail = true;
      final http = _client(store);
      await expectLater(
        http.importCookieHeader('sample=value'),
        throwsStateError,
      );
      await http.persistCookies();
      expect(store.writes, 2);
      expect(
        decodeCookies(
          (await store.read(SecureStore.keySessionCookies))!,
        ).single.value,
        'value',
      );
      await http.persistCookies();
      expect(store.writes, 2);
    },
  );
  test(
    'clear waits for an in-flight write and leaves no cookie blob',
    () async {
      final store = _Store()
        ..writing = Completer<void>()
        ..release = Completer<void>();
      final http = _client(store);
      final import = http.importCookieHeader('sample=old');
      await store.writing!.future;
      final clear = http.clearSession();
      store.release!.complete();
      await Future.wait([import, clear]);
      expect(await store.read(SecureStore.keySessionCookies), isNull);
      expect(await http.exportCookiesJson(), isNull);
      store.writing = null;
      store.release = null;
      await http.importCookieHeader('sample=new');
      expect(
        decodeCookies(
          (await store.read(SecureStore.keySessionCookies))!,
        ).single.value,
        'new',
      );
    },
  );
  test(
    'JSON replacement and concurrent saves persist the final imported value',
    () async {
      final store = _Store();
      final http = _client(store);
      await http.importCookieHeader('sample=old');
      final raw = encodeCookies([
        Cookie('replacement', 'new')
          ..domain = 'lnt.xmu.edu.cn'
          ..path = '/',
      ]);
      await http.importCookiesJson(raw);
      final writes = store.writes;
      await Future.wait(List.generate(10, (_) => http.persistCookies()));
      final cookies = decodeCookies(
        (await store.read(SecureStore.keySessionCookies))!,
      );
      expect(cookies.map((c) => c.name), ['replacement']);
      expect(cookies.single.value, 'new');
      expect(store.writes, writes);
    },
  );
}
