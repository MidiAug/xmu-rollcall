import 'dart:io';
import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xmu_rollcall/core/logging/app_log_dio_interceptor.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/log_redactor.dart';
import 'package:xmu_rollcall/core/network/backoff_interceptor.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/session/cookie_codec.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

class TronHttpClient {
  TronHttpClient({
    required this.store,
    this.sessionKey = SessionKey.owner,
    RateLimiter? rateLimiter,
    Dio? dio,
    CookieJar? cookieJar,
  }) : _limiter = rateLimiter ?? RateLimiter(),
       _dio = dio ?? Dio(),
       _injectedJar = cookieJar;

  final SecureStore store;
  final SessionKey sessionKey;
  final RateLimiter _limiter;
  final Dio _dio;
  final CookieJar? _injectedJar;
  CookieJar? _jar;
  bool _ready = false;
  int _sessionRevision = 0;
  int get sessionRevision => _sessionRevision;
  Future<void>? _initializing;
  final Set<CancelToken> _sessionRequests = {};

  Dio get dio => _dio;
  CookieJar? get cookieJar => _jar;
  RateLimiter get rateLimiter => _limiter;

  Future<void> init() async {
    if (_ready) return;
    return _initializing ??= _init().whenComplete(() => _initializing = null);
  }

  Future<void> _init() async {
    if (_injectedJar != null) {
      _jar = _injectedJar;
    } else {
      _jar = CookieJar();
      final dir = await getApplicationSupportDirectory();
      final cookiePath = Directory(
        '${dir.path}/cookies/${sessionKey.cookieRelativePath}',
      );
      if (await cookiePath.exists()) {
        final legacy = PersistCookieJar(storage: FileStorage(cookiePath.path));
        await migrateLegacyCookies(legacy, store, sessionKey);
      }
    }
    _dio.options
      ..baseUrl = TronEndpoints.baseUrl
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 30)
      ..headers = {
        'User-Agent': TronEndpoints.userAgent,
        'Accept': 'application/json, text/plain, */*',
      };
    _dio.interceptors
      ..clear()
      ..add(CookieManager(_jar!))
      ..add(
        InterceptorsWrapper(
          onResponse: (response, handler) async {
            try {
              await persistCookies();
              handler.next(response);
            } catch (error, stack) {
              AppLog.logAppError(
                error: error,
                stackTrace: stack,
                source: 'cookie_persist',
              );
              handler.next(response);
            }
          },
        ),
      )
      ..add(BackoffInterceptor(_dio, rateLimiter: _limiter))
      ..add(AppLogDioInterceptor());
    await _restoreCookiesFromSecureStore();
    _ready = true;
  }

  Future<void> _restoreCookiesFromSecureStore() async {
    final raw = await store.read(sessionKey.secureCookieKey);
    if (raw == null || raw.isEmpty || _jar == null) return;
    final cookies = decodeCookies(raw);
    if (cookies.isEmpty) return;
    await _jar!.saveFromResponse(Uri.parse(TronEndpoints.baseUrl), cookies);
  }

  Future<void> persistCookies() async {
    if (_jar == null) return;
    final cookies = await _jar!.loadForRequest(
      Uri.parse(TronEndpoints.baseUrl),
    );
    final encoded = encodeCookies(cookies);
    if (await store.read(sessionKey.secureCookieKey) != encoded) {
      await store.write(sessionKey.secureCookieKey, encoded);
    }
  }

  Future<void> importCookieHeader(String cookieHeader) async {
    await init();
    _cancelSessionRequests();
    final cookies = parseCookieHeader(cookieHeader, domain: 'lnt.xmu.edu.cn');
    await _jar!.saveFromResponse(Uri.parse(TronEndpoints.baseUrl), cookies);
    await persistCookies();
  }

  /// Replace jar cookies from a JSON blob (assist import path).
  Future<void> importCookiesJson(String raw) async {
    await init();
    _cancelSessionRequests();
    final cookies = decodeCookies(raw);
    await _jar!.deleteAll();
    if (cookies.isNotEmpty) {
      await _jar!.saveFromResponse(Uri.parse(TronEndpoints.baseUrl), cookies);
    }
    await persistCookies();
  }

  Future<String?> exportCookiesJson() async {
    await init();
    final cookies = await _jar!.loadForRequest(
      Uri.parse(TronEndpoints.baseUrl),
    );
    if (cookies.isEmpty) return null;
    return encodeCookies(cookies);
  }

  Future<void> clearSession() async {
    await init();
    _cancelSessionRequests();
    await _jar!.deleteAll();
    final keys = <String>[sessionKey.secureCookieKey];
    if (sessionKey.isOwner) {
      keys.addAll([SecureStore.keyUserDisplayName, SecureStore.keyUserId]);
    }
    await store.deleteAll(keys);
  }

  Future<Response<T>> getUri<T>(
    Uri uri, {
    Options? options,
    CancelToken? cancelToken,
    RequestPriority priority = RequestPriority.normal,
  }) {
    return _schedule(
      (token, id, waitMs) => _dio.getUri<T>(
        uri,
        options: _trackedOptions(options, id, waitMs),
        cancelToken: token,
      ),
      uri: uri,
      method: 'GET',
      cancelToken: cancelToken,
      priority: priority,
    );
  }

  Future<Response<T>> postUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    RequestPriority priority = RequestPriority.normal,
  }) {
    return _schedule(
      (token, id, waitMs) => _dio.postUri<T>(
        uri,
        data: data,
        options: _trackedOptions(options, id, waitMs),
        cancelToken: token,
      ),
      uri: uri,
      method: 'POST',
      cancelToken: cancelToken,
      priority: priority,
    );
  }

  Future<Response<T>> putUri<T>(
    Uri uri, {
    Object? data,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _schedule(
      (token, id, waitMs) => _dio.putUri<T>(
        uri,
        data: data,
        options: _trackedOptions(options, id, waitMs),
        cancelToken: token,
      ),
      uri: uri,
      method: 'PUT',
      cancelToken: cancelToken,
      priority: RequestPriority.submission,
    );
  }

  /// Login hops: no follow, accept 3xx, treat body as text.
  Future<Response<dynamic>> hop(
    String method,
    Uri uri, {
    Object? data,
    String? contentType,
  }) {
    return _schedule(
      (token, id, waitMs) {
        return _dio.requestUri<dynamic>(
          uri,
          data: data,
          cancelToken: token,
          options: Options(
            method: method,
            extra: {'retrySafe': false, 'requestId': id, 'queueMs': waitMs},
            followRedirects: false,
            maxRedirects: 0,
            responseType: ResponseType.plain,
            contentType: contentType,
            validateStatus: (s) => s != null && s < 500,
            headers: {
              'User-Agent': TronEndpoints.userAgent,
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          ),
        );
      },
      uri: uri,
      method: method,
    );
  }

  void _cancelSessionRequests() {
    _sessionRevision++;
    for (final token in _sessionRequests.toList()) {
      token.cancel('账号会话已变更');
    }
  }

  Options _trackedOptions(Options? options, String id, int waitMs) =>
      (options ?? Options()).copyWith(
        extra: {...?options?.extra, 'requestId': id, 'queueMs': waitMs},
      );

  Future<Response<T>> _schedule<T>(
    Future<Response<T>> Function(CancelToken, String, int) action, {
    required Uri uri,
    required String method,
    CancelToken? cancelToken,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    final token = CancelToken();
    if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
    if (cancelToken != null) {
      unawaited(cancelToken.whenCancel.then((error) => token.cancel(error)));
    }
    _sessionRequests.add(token);
    final queuedAt = DateTime.now();
    final requestId = AppLog.newOpId();
    var started = false;
    try {
      return await _limiter.schedule(
        () {
          started = true;
          final waitMs = DateTime.now().difference(queuedAt).inMilliseconds;
          if (waitMs >= 1000) {
            AppLog.event(
              'http.queue.wait',
              fields: {
                'requestId': requestId,
                'method': method,
                'path': uri.path,
                'durationMs': waitMs,
                'priority': priority.name,
              },
            );
          }
          return action(token, requestId, waitMs);
        },
        cancelToken: token,
        priority: priority,
      );
    } catch (error, stack) {
      if (!started) {
        AppLog.event(
          'http.queue.error',
          level: 'W',
          fields: {
            ...LogRedactor.exceptionFields(error: error, stackTrace: stack),
            'requestId': requestId,
            'method': method,
            'path': uri.path,
            'queueMs': DateTime.now().difference(queuedAt).inMilliseconds,
            'priority': priority.name,
          },
        );
      }
      rethrow;
    } finally {
      _sessionRequests.remove(token);
    }
  }
}

/// Copy legacy plaintext cookies to secure storage before removing the old copy.
Future<void> migrateLegacyCookies(
  CookieJar legacy,
  SecureStore store,
  SessionKey key,
) async {
  final stored = await store.read(key.secureCookieKey);
  if (stored == null || stored.isEmpty) {
    final cookies = await legacy.loadForRequest(
      Uri.parse(TronEndpoints.baseUrl),
    );
    if (cookies.isNotEmpty) {
      await store.write(key.secureCookieKey, encodeCookies(cookies));
    }
  }
  await legacy.deleteAll();
}
