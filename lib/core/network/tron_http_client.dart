import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xmu_rollcall/core/logging/app_log_dio_interceptor.dart';
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
  })  : _limiter = rateLimiter ?? RateLimiter(),
        _dio = dio ?? Dio(),
        _injectedJar = cookieJar;

  final SecureStore store;
  final SessionKey sessionKey;
  final RateLimiter _limiter;
  final Dio _dio;
  final CookieJar? _injectedJar;
  CookieJar? _jar;
  bool _ready = false;

  Dio get dio => _dio;
  CookieJar? get cookieJar => _jar;
  RateLimiter get rateLimiter => _limiter;

  Future<void> init() async {
    if (_ready) return;
    if (_injectedJar != null) {
      _jar = _injectedJar;
    } else {
      final dir = await getApplicationSupportDirectory();
      final cookiePath = Directory(
        '${dir.path}/cookies/${sessionKey.cookieRelativePath}',
      );
      if (!await cookiePath.exists()) {
        await cookiePath.create(recursive: true);
      }
      _jar = PersistCookieJar(storage: FileStorage(cookiePath.path));
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
      ..add(BackoffInterceptor(_dio))
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
    final cookies =
        await _jar!.loadForRequest(Uri.parse(TronEndpoints.baseUrl));
    await store.write(sessionKey.secureCookieKey, encodeCookies(cookies));
  }

  Future<void> importCookieHeader(String cookieHeader) async {
    await init();
    final cookies = parseCookieHeader(
      cookieHeader,
      domain: 'lnt.xmu.edu.cn',
    );
    await _jar!.saveFromResponse(Uri.parse(TronEndpoints.baseUrl), cookies);
    await persistCookies();
  }

  /// Replace jar cookies from a JSON blob (assist import path).
  Future<void> importCookiesJson(String raw) async {
    await init();
    final cookies = decodeCookies(raw);
    await _jar!.deleteAll();
    if (cookies.isNotEmpty) {
      await _jar!.saveFromResponse(Uri.parse(TronEndpoints.baseUrl), cookies);
    }
    await persistCookies();
  }

  Future<String?> exportCookiesJson() async {
    await init();
    final cookies =
        await _jar!.loadForRequest(Uri.parse(TronEndpoints.baseUrl));
    if (cookies.isEmpty) return null;
    return encodeCookies(cookies);
  }

  Future<void> clearSession() async {
    await init();
    await _jar!.deleteAll();
    final keys = <String>[sessionKey.secureCookieKey];
    if (sessionKey.isOwner) {
      keys.addAll([
        SecureStore.keyUserDisplayName,
        SecureStore.keyUserId,
      ]);
    }
    await store.deleteAll(keys);
  }

  Future<Response<T>> getUri<T>(Uri uri, {Options? options}) {
    return _limiter.schedule(() => _dio.getUri<T>(uri, options: options));
  }

  Future<Response<T>> postUri<T>(Uri uri, {Object? data, Options? options}) {
    return _limiter
        .schedule(() => _dio.postUri<T>(uri, data: data, options: options));
  }

  Future<Response<T>> putUri<T>(Uri uri, {Object? data, Options? options}) {
    return _limiter
        .schedule(() => _dio.putUri<T>(uri, data: data, options: options));
  }

  /// Login hops: no follow, accept 3xx, treat body as text.
  Future<Response<dynamic>> hop(
    String method,
    Uri uri, {
    Object? data,
    String? contentType,
  }) {
    return _limiter.schedule(() {
      return _dio.requestUri<dynamic>(
        uri,
        data: data,
        options: Options(
          method: method,
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
    });
  }
}
