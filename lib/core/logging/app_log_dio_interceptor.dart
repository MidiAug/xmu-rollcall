import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/log_redactor.dart';

/// Whitelist HTTP metadata → [AppLog]. Does not pass Dio objects through.
class AppLogDioInterceptor extends Interceptor {
  static const _signPaths = [
    'answer_number_rollcall',
    'answer_qr_rollcall',
    'student_rollcalls',
  ];

  static const _queryAllow = {
    'api_version',
    'page',
    'page_size',
    'per_page',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_shouldLog(options)) {
      options.extra['_applog_t0'] = DateTime.now().millisecondsSinceEpoch;
      final opId = options.extra['opId'] as String?;
      AppLog.event(
        'http.request',
        level: 'I',
        opId: opId,
        fields: {
          'method': options.method,
          'path': _cleanPath(options.uri),
          'query': _filterQuery(options.uri),
          'request': _requestSummary(options.data),
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
      AppLog.event(
        'http.response',
        level: 'I',
        opId: options.extra['opId'] as String?,
        fields: {
          'method': options.method,
          'path': _cleanPath(options.uri),
          'status': response.statusCode,
          if (latency != null) 'latencyMs': latency,
          'response': _responseSummary(response.data),
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
      AppLog.event(
        'http.error',
        level: 'E',
        opId: options.extra['opId'] as String?,
        fields: {
          'method': options.method,
          'path': _cleanPath(options.uri),
          'status': err.response?.statusCode,
          if (latency != null) 'latencyMs': latency,
          'errorType': err.type.name,
          'message': err.type.name,
          'response': _responseSummary(err.response?.data),
          if (options.extra['rollcallId'] != null)
            'rollcallId': options.extra['rollcallId'],
        },
      );
    }
    handler.next(err);
  }

  bool _shouldLog(RequestOptions options) {
    if (options.extra['opId'] != null) return true;
    final path = options.uri.path;
    if (path.contains('/api/rollcall/') && path.endsWith('/answer')) {
      return true;
    }
    for (final frag in _signPaths) {
      if (path.contains(frag)) return true;
    }
    return false;
  }

  String _cleanPath(Uri uri) => uri.path;

  Map<String, dynamic> _filterQuery(Uri uri) {
    final out = <String, dynamic>{};
    uri.queryParameters.forEach((k, v) {
      if (_queryAllow.contains(k)) {
        out[k] = v;
      } else {
        out[k] = '[omit]';
      }
    });
    return out;
  }

  Map<String, dynamic>? _requestSummary(Object? data) {
    if (data == null) return null;
    Map<String, dynamic>? map;
    if (data is Map) {
      map = Map<String, dynamic>.from(data);
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) map = Map<String, dynamic>.from(decoded);
      } catch (_) {
        return {'len': data.length};
      }
    }
    if (map == null) return null;
    final out = <String, dynamic>{};
    if (map['deviceId'] is String) {
      final id = map['deviceId'] as String;
      out['deviceIdSuffix'] =
          id.length <= 6 ? id : id.substring(id.length - 6);
    }
    if (map['numberCode'] != null) out['numberCode'] = map['numberCode'];
    if (map['accuracy'] != null) out['accuracy'] = map['accuracy'];
    if (map['latitude'] is num) {
      out['latitude'] =
          double.parse((map['latitude'] as num).toStringAsFixed(5));
    }
    if (map['longitude'] is num) {
      out['longitude'] =
          double.parse((map['longitude'] as num).toStringAsFixed(5));
    }
    if (map['data'] is String) {
      final raw = map['data'] as String;
      out['payloadLen'] = raw.length;
      out['payloadSha256Prefix'] =
          sha256.convert(utf8.encode(raw)).toString().substring(0, 8);
    }
    return out;
  }

  Map<String, dynamic>? _responseSummary(Object? data) {
    if (data == null) return null;
    Map<String, dynamic>? map;
    if (data is Map) {
      map = Map<String, dynamic>.from(data);
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) map = Map<String, dynamic>.from(decoded);
      } catch (_) {
        return {
          'message': LogRedactor.truncateUtf8(data, LogRedactor.maxUtf8Bytes),
        };
      }
    }
    if (map == null) return null;
    final out = <String, dynamic>{};
    for (final key in ['message', 'distance', 'status', 'error', 'code']) {
      if (map.containsKey(key)) out[key] = map[key];
    }
    // Keep other keys as key names only.
    for (final key in map.keys) {
      if (!out.containsKey(key)) out[key] = '[omit]';
    }
    final encoded = utf8.encode(jsonEncode(out));
    if (encoded.length > LogRedactor.maxUtf8Bytes) {
      return LogRedactor.redactFields(out);
    }
    return out;
  }
}
