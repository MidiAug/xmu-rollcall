import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';

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
    final delayMs = delay.inMilliseconds + 100 * prior;

    AppLog.event(
      'http.retry',
      level: 'W',
      opId: err.requestOptions.extra['opId'] as String?,
      fields: {
        'attempt': prior + 1,
        'status': status,
        'delayMs': delayMs,
        'method': err.requestOptions.method,
        'path': err.requestOptions.uri.path,
      },
    );

    await Future<void>.delayed(Duration(milliseconds: delayMs));

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
