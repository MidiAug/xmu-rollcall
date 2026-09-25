import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/ids_password.dart';

class AuthRepository {
  AuthRepository({
    required this.http,
    required this.store,
  });

  final TronHttpClient http;
  final SecureStore store;

  Future<String?> lastUsername() => store.read(SecureStore.keyLastUsername);

  Future<String?> savedPassword() => store.read(SecureStore.keyOwnerPassword);

  Future<bool> hasStoredCookies() async {
    final raw = await store.read(SessionKey.owner.secureCookieKey);
    return raw != null && raw.isNotEmpty;
  }

  /// xmulogin type=3: IDS form POST → OAuth code → token → TronClass session.
  Future<UserProfile> signIn({
    required String username,
    required String password,
  }) async {
    await http.init();
    await http.clearSession();

    AppLog.event('login.step', fields: {'step': 'fetch_form'});
    final form = await _fetchLoginForm();
    if (idsFormLooksLikeCaptcha(form.html)) {
      AppLog.event(
        'login.step',
        level: 'W',
        fields: {'step': 'captcha'},
      );
      throw AuthException('登录页出现验证码，请稍后再试，勿连续重试');
    }
    final fields = parseIdsLoginForm(form.html);
    if (fields == null) {
      throw AuthException('登录页面异常，请稍后再试');
    }

    AppLog.event('login.step', fields: {'step': 'post_ids'});
    final encrypted = encryptIdsPassword(password, fields.salt);
    final posted = await http.hop(
      'POST',
      form.url,
      data: {
        'username': username,
        'password': encrypted,
        'captcha': '',
        '_eventId': 'submit',
        'cllt': 'userNameLogin',
        'dllt': 'generalLogin',
        'lt': '',
        'execution': fields.execution,
      },
      contentType: Headers.formUrlEncodedContentType,
    );

    final postLoc = posted.headers.value('location');
    if (postLoc == null || postLoc.isEmpty) {
      final body = posted.data?.toString() ?? '';
      if (idsFormLooksLikeCaptcha(body)) {
        AppLog.event(
          'login.step',
          level: 'W',
          fields: {'step': 'captcha', 'status': posted.statusCode},
        );
        throw AuthException('需要验证码，请稍后再试');
      }
      AppLog.event(
        'login.step',
        level: 'W',
        fields: {'step': 'bad_credentials', 'status': posted.statusCode},
      );
      throw AuthException('学号或密码不正确');
    }

    AppLog.event('login.step', fields: {'step': 'follow_code'});
    final code = await _followToAuthCode(form.url.resolve(postLoc));
    AppLog.event('login.step', fields: {'step': 'oauth_token'});
    final profile = await completeOAuthCode(code);
    await store.write(SecureStore.keyLastUsername, username);
    await store.write(SecureStore.keyOwnerPassword, password);
    AppLog.event(
      'login.step',
      fields: {'step': 'done', 'userId': profile.id},
    );
    return profile;
  }

  Future<({Uri url, String html})> _fetchLoginForm() async {
    var uri = TronEndpoints.oauthAuthorizeUri();
    for (var i = 0; i < 12; i++) {
      final res = await http.hop('GET', uri);
      final loc = res.headers.value('location');
      final html = res.data?.toString() ?? '';
      if (html.contains('pwdEncryptSalt')) {
        return (url: uri, html: html);
      }
      if (loc != null && loc.isNotEmpty) {
        uri = uri.resolve(loc);
        continue;
      }
      throw AuthException('无法打开统一身份认证，请检查网络后重试');
    }
    throw AuthException('登录跳转次数过多，请稍后重试');
  }

  Future<String> _followToAuthCode(Uri start) async {
    var uri = start;
    for (var i = 0; i < 12; i++) {
      final code = uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) return code;

      final res = await http.hop('GET', uri);
      final loc = res.headers.value('location');
      if (loc == null || loc.isEmpty) {
        throw AuthException('登录未完成，请重试');
      }
      uri = uri.resolve(loc);
      final nextCode = uri.queryParameters['code'];
      if (nextCode != null && nextCode.isNotEmpty) return nextCode;
    }
    throw AuthException('登录跳转次数过多，请稍后重试');
  }

  Future<UserProfile> completeOAuthCode(String code) async {
    await http.init();
    final tokenRes = await http.dio.post<Map<String, dynamic>>(
      TronEndpoints.tokenUri().toString(),
      data: {
        'client_id': TronEndpoints.clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': TronEndpoints.mobileCallback,
        'scope': 'openid',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'User-Agent': TronEndpoints.userAgent},
      ),
    );
    final accessToken = tokenRes.data?['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw AuthException('登录未完成，请重试');
    }

    await http.postUri<dynamic>(
      TronEndpoints.loginAccessToken(),
      data: {'access_token': accessToken, 'org_id': 1},
    );
    await http.persistCookies();
    return fetchProfile();
  }

  Future<UserProfile?> tryRestoreSession() async {
    await http.init();
    try {
      return await fetchProfile();
    } on DioException {
      return null;
    } on AuthException {
      return null;
    }
  }

  Future<UserProfile> fetchProfile() async {
    final res = await http.getUri<Map<String, dynamic>>(TronEndpoints.profile());
    final data = res.data;
    if (data == null) {
      throw AuthException('资料接口无数据');
    }
    final profile = UserProfile.fromJson(data);
    await store.write(SecureStore.keyUserDisplayName, profile.name);
    await store.write(SecureStore.keyUserId, '${profile.id}');
    await http.persistCookies();
    return profile;
  }

  Future<void> signOut() async {
    await http.clearSession();
    await store.delete(SecureStore.keyOwnerPassword);
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
