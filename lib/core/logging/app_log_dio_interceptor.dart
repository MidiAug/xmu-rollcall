import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/http_log_summary.dart';
import 'package:xmu_rollcall/core/logging/log_redactor.dart';

/// Path-aware HTTP diagnostics → [AppLog]. Does not pass Dio objects through.
class AppLogDioInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra.putIfAbsent('requestId', AppLog.newOpId);
    options.extra.putIfAbsent(
      '_applog_total_t0',
      () =>
          DateTime.now().millisecondsSinceEpoch -
          (options.extra['queueMs'] as int? ?? 0),
    );
    if (_shouldLog(options)) {
      options.extra['_applog_t0'] = DateTime.now().millisecondsSinceEpoch;
      final opId = options.extra['opId'] as String?;
      AppLog.event(
        'http.request',
        level: 'I',
        opId: opId,
        fields: {
          'requestId': options.extra['requestId'],
          'queueMs': options.extra['queueMs'],
          'method': options.method,
          'path': _cleanPath(options.uri),
          'query': HttpLogSummary.filterQuery(options.uri),
          'request': HttpLogSummary.requestSummary(options.data),
          if (options.extra['rollcallId'] != null)
            'rollcallId': options.extra['rollcallId'],
          'attempt': (options.extra['backoff_attempt'] as int? ?? 0) + 1,
        },
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    if (_shouldLog(options)) {
      final t0 = options.extra['_applog_t0'] as int?;
      final latency = t0 == null
          ? null
          : DateTime.now().millisecondsSinceEpoch - t0;
      final path = _cleanPath(options.uri);
      final summary = HttpLogSummary.responseSummary(response.data, path: path);
      AppLog.event(
        'http.response',
        level: 'I',
        opId: options.extra['opId'] as String?,
        maxFieldBytes: LogRedactor.maxProjectionUtf8Bytes,
        fields: {
          'requestId': options.extra['requestId'],
          'queueMs': options.extra['queueMs'],
          'method': options.method,
          'path': path,
          'status': response.statusCode,
          'contentType': response.headers.value(Headers.contentTypeHeader),
          'responseType': response.data.runtimeType.toString(),
          'latencyMs': ?latency,
          'totalMs': _totalMs(options),
          'response': ?summary,
          if (options.extra['rollcallId'] != null)
            'rollcallId': options.extra['rollcallId'],
        },
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    if (_shouldLog(options)) {
      final t0 = options.extra['_applog_t0'] as int?;
      final latency = t0 == null
          ? null
          : DateTime.now().millisecondsSinceEpoch - t0;
      final path = _cleanPath(options.uri);
      final summary = HttpLogSummary.responseSummary(
        err.response?.data,
        path: path,
      );
      AppLog.event(
        'http.error',
        level: 'E',
        opId: options.extra['opId'] as String?,
        maxFieldBytes: LogRedactor.maxProjectionUtf8Bytes,
        fields: {
          'requestId': options.extra['requestId'],
          'queueMs': options.extra['queueMs'],
          'method': options.method,
          'path': path,
          'status': err.response?.statusCode,
          'contentType': err.response?.headers.value(Headers.contentTypeHeader),
          'responseType': err.response?.data.runtimeType.toString(),
          'latencyMs': ?latency,
          'totalMs': _totalMs(options),
          ...LogRedactor.exceptionFields(
            error: err,
            stackTrace: err.stackTrace,
          ),
          'errorType': err.type.name,
          'message': err.type.name,
          'response': ?summary,
          if (options.extra['rollcallId'] != null)
            'rollcallId': options.extra['rollcallId'],
        },
      );
    }
    handler.next(err);
  }

  bool _shouldLog(RequestOptions options) {
    return HttpLogSummary.shouldLog(
      path: options.uri.path,
      opId: options.extra['opId'] as String?,
      method: options.method,
    );
  }

  int? _totalMs(RequestOptions options) {
    final start = options.extra['_applog_total_t0'] as int?;
    return start == null ? null : DateTime.now().millisecondsSinceEpoch - start;
  }

  String _cleanPath(Uri uri) => uri.path;
}
