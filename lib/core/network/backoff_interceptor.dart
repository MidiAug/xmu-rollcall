import 'dart:io';
import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';

/// On 429 / 5xx, delay then retry using the same [Dio] (keeps CookieJar).
class BackoffInterceptor extends Interceptor {
  BackoffInterceptor(
    this._dio, {
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.rateLimiter,
  });

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;
  final RateLimiter? rateLimiter;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode ?? 0;
    final opts = err.requestOptions;
    final safe =
        opts.extra['retrySafe'] == true ||
        (opts.extra['retrySafe'] != false &&
            (opts.method == 'GET' || opts.method == 'HEAD'));
    final retryable = safe && (status == 429 || status >= 500);
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

    try {
      var retryDelay = Duration(milliseconds: delayMs);
      final header = err.response?.headers.value('retry-after');
      if (header != null) {
        Duration? serverDelay;
        final seconds = int.tryParse(header);
        if (seconds != null && seconds >= 0) {
          serverDelay = Duration(seconds: seconds);
        } else {
          try {
            serverDelay = HttpDate.parse(header).difference(DateTime.now());
          } on FormatException {
            // Ignore malformed server hints; retain exponential backoff.
          }
        }
        if (serverDelay != null && serverDelay > retryDelay) {
          retryDelay = serverDelay;
        }
      }
      final token = opts.cancelToken;
      if (token?.isCancelled == true) throw token!.cancelError!;
      await Future.any<void>([
        Future<void>.delayed(retryDelay),
        if (token != null) token.whenCancel.then<void>((error) => throw error),
      ]);
      await rateLimiter?.waitForStart(cancelToken: token);
      if (token?.isCancelled == true) throw token!.cancelError!;
      opts.extra['backoff_attempt'] = prior + 1;
      final response = await _dio.fetch(opts);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}
