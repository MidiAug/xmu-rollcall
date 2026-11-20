import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

class _Adapter implements HttpClientAdapter {
  Completer<ResponseBody>? pending;
  Completer<void>? entered;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) async {
    entered?.complete();
    return pending?.future ?? Future.value(ResponseBody.fromString('{}', 200));
  }
}

void main() {
  test(
    'shared caller token still cancels live requests after completed work',
    () async {
      final adapter = _Adapter();
      final http = TronHttpClient(
        store: SecureStore.memory(),
        cookieJar: CookieJar(),
        dio: Dio()..httpClientAdapter = adapter,
        rateLimiter: RateLimiter(
          minInterval: Duration.zero,
          maxPerMinute: 10000,
        ),
      );
      await http.init();
      final token = CancelToken();
      final uri = Uri.parse('https://lnt.xmu.edu.cn/api/test');
      for (var i = 0; i < 20; i++) {
        expect(
          (await http.getUri<dynamic>(uri, cancelToken: token)).statusCode,
          200,
        );
      }
      adapter.pending = Completer<ResponseBody>();
      adapter.entered = Completer<void>();
      final request = http.getUri<dynamic>(uri, cancelToken: token);
      final cancelled = expectLater(
        request,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await adapter.entered!.future;
      token.cancel('page closed');
      await cancelled;
      adapter.pending!.complete(ResponseBody.fromString('{}', 200));
      adapter.pending = null;
      adapter.entered = null;
      expect((await http.getUri<dynamic>(uri)).statusCode, 200);
    },
  );
}
