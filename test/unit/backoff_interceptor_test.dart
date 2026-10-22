import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/backoff_interceptor.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';

class Adapter implements HttpClientAdapter {
  int calls = 0;
  String? retryAfter;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    calls++;
    return ResponseBody.fromString(
      '{}',
      calls == 1 ? 503 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        if (retryAfter != null) 'retry-after': [retryAfter!],
      },
    );
  }
}

void main() {
  test('GET retries through shared rate gate without deadlock', () async {
    final adapter = Adapter();
    final limiter = RateLimiter(minInterval: Duration.zero, maxConcurrent: 1);
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(
      BackoffInterceptor(dio, baseDelay: Duration.zero, rateLimiter: limiter),
    );
    final response = await limiter.schedule(
      () => dio.get('https://example.test/list'),
    );
    expect(response.statusCode, 200);
    expect(adapter.calls, 2);
    dio.close();
  });

  for (final method in ['PUT', 'POST']) {
    test('$method submissions are not replayed automatically', () async {
      final adapter = Adapter();
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(BackoffInterceptor(dio, baseDelay: Duration.zero));
      await expectLater(
        dio.request(
          'https://example.test/submit',
          options: Options(method: method),
        ),
        throwsA(isA<DioException>()),
      );
      expect(adapter.calls, 1);
      dio.close();
    });
  }

  test('Retry-After minimum is respected', () async {
    final adapter = Adapter()..retryAfter = '1';
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(BackoffInterceptor(dio, baseDelay: Duration.zero));
    final elapsed = Stopwatch()..start();
    await dio.get('https://example.test/list');
    expect(elapsed.elapsedMilliseconds, greaterThanOrEqualTo(950));
    expect(adapter.calls, 2);
    dio.close();
  });

  test('cancellation during backoff prevents replay', () async {
    final adapter = Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(
      BackoffInterceptor(dio, baseDelay: const Duration(milliseconds: 100)),
    );
    final token = CancelToken();
    final result = dio.get('https://example.test/list', cancelToken: token);
    final check = expectLater(
      result,
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    token.cancel();
    await check;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(adapter.calls, 1);
    dio.close();
  });
}
