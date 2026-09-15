import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xmu_rollcall/core/network/backoff_interceptor.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';

Map<String, dynamic> _cookieToJson(Cookie c) => {
      'name': c.name,
      'value': c.value,
      'domain': c.domain,
      'path': c.path,
      'secure': c.secure,
      'httpOnly': c.httpOnly,
    };

Cookie _cookieFromJson(Map<String, dynamic> json) {
  return Cookie(json['name'] as String, json['value'] as String)
    ..domain = json['domain'] as String?
    ..path = json['path'] as String? ?? '/'
    ..secure = json['secure'] as bool? ?? false
    ..httpOnly = json['httpOnly'] as bool? ?? false;
}

class TronHttpClient {
  TronHttpClient({
    required this.store,
    RateLimiter? rateLimiter,
    Dio? dio,
  })  : _limiter = rateLimiter ?? RateLimiter(),
        _dio = dio ?? Dio();

  final SecureStore store;
  final RateLimiter _limiter;
  final Dio _dio;
  CookieJar? _jar;
  bool _ready = false;

  Dio get dio => _dio;
  CookieJar? get cookieJar => _jar;

  Future<void> init() async {
    if (_ready) return;
    final dir = await getApplicationSupportDirectory();
    final cookiePath = Directory('${dir.path}/cookies');
    if (!await cookiePath.exists()) {
      await cookiePath.create(recursive: true);
    }
    _jar = PersistCookieJar(storage: FileStorage(cookiePath.path));
    _dio.options
      ..baseUrl = TronEndpoints.baseUrl
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 30)
      ..headers = {
        'User-Agent': TronEndpoints.userAgent,
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/json',
      };
    _dio.interceptors
      ..clear()
      ..add(CookieManager(_jar!))
      ..add(BackoffInterceptor(_dio));
    await _restoreCookiesFromSecureStore();
    _ready = true;
  }

  Future<void> _restoreCookiesFromSecureStore() async {
    final raw = await store.read(SecureStore.keySessionCookies);
    if (raw == null || raw.isEmpty || _jar == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final cookies = list
          .map((e) => _cookieFromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _jar!.saveFromResponse(Uri.parse(TronEndpoints.baseUrl), cookies);
    } catch (_) {
      // Corrupt blob — ignore; user can re-login.
    }
  }

  Future<void> persistCookies() async {
    if (_jar == null) return;
    final cookies =
        await _jar!.loadForRequest(Uri.parse(TronEndpoints.baseUrl));
    final encoded = jsonEncode(cookies.map(_cookieToJson).toList());
    await store.write(SecureStore.keySessionCookies, encoded);
  }

  Future<void> importCookieHeader(String cookieHeader) async {
    await init();
    final parts = cookieHeader.split(';');
    final cookies = <Cookie>[];
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final name = trimmed.substring(0, eq).trim();
      final value = trimmed.substring(eq + 1).trim();
      cookies.add(
        Cookie(name, value)
          ..domain = 'lnt.xmu.edu.cn'
          ..path = '/',
      );
    }
    await _jar!.saveFromResponse(Uri.parse(TronEndpoints.baseUrl), cookies);
    await persistCookies();
  }

  Future<void> clearSession() async {
    await init();
    await _jar!.deleteAll();
    await store.deleteAll([
      SecureStore.keySessionCookies,
      SecureStore.keyUserDisplayName,
      SecureStore.keyUserId,
    ]);
  }

  Future<Response<T>> getUri<T>(Uri uri) {
    return _limiter.schedule(() => _dio.getUri<T>(uri));
  }

  Future<Response<T>> postUri<T>(Uri uri, {Object? data}) {
    return _limiter.schedule(() => _dio.postUri<T>(uri, data: data));
  }

  Future<Response<T>> putUri<T>(Uri uri, {Object? data}) {
    return _limiter.schedule(() => _dio.putUri<T>(uri, data: data));
  }
}
