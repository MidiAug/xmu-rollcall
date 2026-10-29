import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/log_redactor.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/session/cookie_codec.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/auth/ids_auth.dart';

class AcademicApplicationDenied extends FormatException {
  const AcademicApplicationDenied() : super('当前账号无该成绩应用权限');
}

class AcademicSessionRequired implements Exception {
  const AcademicSessionRequired();
}

class AcademicLoginRequired extends FormatException {
  const AcademicLoginRequired([super.message = '请重新登录账号以连接教务课表']);
}

/// Independent, per-identity JW/IDS jar. No TronClass access token is forwarded.
class AcademicSession {
  AcademicSession({required this.store, Dio? dio, RateLimiter? limiter})
    : dio = dio ?? Dio(),
      limiter = limiter ?? RateLimiter() {
    this.dio.options.connectTimeout = const Duration(seconds: 20);
    this.dio.options.receiveTimeout = const Duration(seconds: 30);
    this.dio.interceptors.add(CookieManager(jar));
  }
  final SecureStore store;
  final Dio dio;
  final RateLimiter limiter;
  final CookieJar jar = CookieJar();
  int? _boundUid;
  Future<bool> Function()? identityGuard;
  Future<bool> _identityCurrent(int uid) async => identityGuard != null
      ? identityGuard!()
      : await store.read(SecureStore.keyUserId) == '$uid';
  static final jw = Uri.parse('https://jw.xmu.edu.cn');
  static final ids = Uri.parse('https://ids.xmu.edu.cn');
  static String credentialKey(int uid) => 'academic_session_v1_$uid';

  Future<Response<dynamic>> hop(
    String method,
    Uri uri, {
    Object? data,
    String? contentType,
    Map<String, dynamic>? headers,
  }) {
    if (uri.scheme != 'https' || !{jw.host, ids.host}.contains(uri.host)) {
      throw const FormatException('教务登录跳转地址异常');
    }
    final watch = Stopwatch()..start();
    return limiter
        .schedule(() async {
          if (_boundUid != null && !await _identityCurrent(_boundUid!)) {
            throw StateError('账号已切换');
          }
          return dio.requestUri<dynamic>(
            uri,
            data: data,
            options: Options(
              method: method,
              followRedirects: false,
              maxRedirects: 0,
              responseType: ResponseType.plain,
              contentType: contentType,
              validateStatus: (s) => s != null && s < 500,
              headers: {'User-Agent': TronEndpoints.userAgent, ...?headers},
            ),
          );
        }, priority: RequestPriority.background)
        .then(
          (response) {
            AppLog.event(
              'academic.http.result',
              fields: {
                'method': method,
                'host': uri.host,
                'path': uri.path,
                'status': response.statusCode,
                'elapsedMs': watch.elapsedMilliseconds,
              },
            );
            return response;
          },
          onError: (Object error, StackTrace stack) {
            AppLog.event(
              'academic.http.error',
              level: 'W',
              fields: {
                ...LogRedactor.exceptionFields(error: error),
                'host': uri.host,
                'path': uri.path,
                'elapsedMs': watch.elapsedMilliseconds,
              },
            );
            Error.throwWithStackTrace(error, stack);
          },
        );
  }

  Future<Uri> open(Uri uri, {String? username, String? password}) async {
    var submitted = false;
    for (var i = 0; i < 16; i++) {
      final response = await hop('GET', uri);
      // Anonymous appShow currently returns 404. Only this entry permits CAS bootstrap.
      if (response.statusCode == 404 &&
          uri.host == jw.host &&
          uri.path == '/appShow') {
        throw const AcademicSessionRequired();
      }
      if (response.statusCode == 429 || response.statusCode == 403) {
        throw const FormatException('教务暂时拒绝访问，请稍后重试');
      }
      final html = '${response.data ?? ''}';
      if (html.contains('pwdEncryptSalt')) {
        if (submitted || username == null || password == null) {
          throw const AcademicLoginRequired();
        }
        submitted = true;
        try {
          uri = await IdsAuth(hop).submit(
            url: uri,
            html: html,
            username: username,
            password: password,
          );
        } on FormatException catch (error) {
          if (error.source == null &&
              const {
                '需要验证码，请在统一认证中完成登录',
                '统一认证未通过，请检查账号密码',
              }.contains(error.message)) {
            throw AcademicLoginRequired(error.message);
          }
          rethrow;
        }
        continue;
      }
      final location = response.headers.value('location');
      if (location != null &&
          location.isNotEmpty &&
          {301, 302, 303, 307, 308}.contains(response.statusCode)) {
        uri = uri.resolve(location);
        if (uri.host == jw.host && uri.path == '/resources/html/403.html') {
          // A denied application is not an expired CAS session; never fetch its HTTP error page.
          throw const AcademicApplicationDenied();
        }
        continue;
      }
      if (response.statusCode != 200 || uri.host == ids.host) {
        throw const FormatException('教务会话未建立');
      }
      return uri;
    }
    throw const FormatException('教务登录跳转过多');
  }

  Future<Map<String, dynamic>> json(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? headers,
  }) async {
    final response = await hop(
      data == null ? 'GET' : 'POST',
      jw.resolve(path),
      data: data,
      contentType: data == null ? null : Headers.formUrlEncodedContentType,
      headers: headers,
    );
    if ({301, 302, 303, 307, 308, 401}.contains(response.statusCode)) {
      throw const AcademicLoginRequired();
    }
    if (response.statusCode == 403) {
      throw const FormatException('教务拒绝访问（403），请稍后重试');
    }
    if (response.statusCode == 429) {
      throw const FormatException('教务请求过于频繁，请稍后重试');
    }
    if (response.statusCode != 200) throw const FormatException('教务会话失效或暂不可用');
    final decoded = jsonDecode('${response.data}');
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('教务数据格式异常');
    }
    return decoded;
  }

  Future<void> connect(
    int uid, {
    required String applicationId,
    CookieJar? sso,
    String? username,
    String? password,
  }) async {
    _boundUid = uid;
    final raw = await store.read(credentialKey(uid));
    if (raw != null) {
      final saved = jsonDecode(raw) as Map;
      for (final origin in [jw, ids]) {
        if (saved[origin.host] is String) {
          await jar.saveFromResponse(
            origin,
            decodeCookies(saved[origin.host] as String),
          );
        }
      }
    }
    if (sso != null) {
      await jar.saveFromResponse(
        ids,
        await sso.loadForRequest(ids.resolve('/authserver/login')),
      );
    }
    final app = jw
        .resolve('/appShow')
        .replace(queryParameters: {'appId': applicationId});
    try {
      await open(app, username: username, password: password);
    } on AcademicSessionRequired {
      await open(
        ids
            .resolve('/authserver/login')
            .replace(
              queryParameters: {
                'type': 'userNameLogin',
                'service':
                    'https://jw.xmu.edu.cn/login?service=https://jw.xmu.edu.cn/new/index.html',
              },
            ),
        username: username,
        password: password,
      );
      await open(app);
    }
  }

  Future<void> persist(int uid) async {
    if (!await _identityCurrent(uid)) throw StateError('账号已切换');
    await store.write(
      credentialKey(uid),
      jsonEncode({
        for (final origin in [jw, ids])
          origin.host: encodeCookies(
            await jar.loadForRequest(
              origin.resolve(
                origin == ids ? '/authserver/login' : '/gsapp/sys/wdkbapp/',
              ),
            ),
          ),
      }),
    );
  }

  void close() => dio.close();
}
