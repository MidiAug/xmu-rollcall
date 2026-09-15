import 'package:dio/dio.dart';

/// On 429 / 5xx, delay then retry using the same [Dio] (keeps CookieJar).
class BackoffInterceptor extends Interceptor {
  BackoffInterceptor(
    this._dio, {
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
  });

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode ?? 0;
    final retryable = status == 429 || status >= 500;
    final prior = err.requestOptions.extra['backoff_attempt'] as int? ?? 0;
    if (!retryable || prior >= maxRetries) {
      return handler.next(err);
    }

    final delay = baseDelay * (1 << prior);
    await Future<void>.delayed(delay + Duration(milliseconds: 100 * prior));

    final opts = err.requestOptions;
    opts.extra['backoff_attempt'] = prior + 1;
    try {
      final response = await _dio.fetch(opts);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}
