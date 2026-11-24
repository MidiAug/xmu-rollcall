import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/session/cookie_codec.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/ids_auth.dart';

class AuthRepository {
  AuthRepository({
    required this.http,
    required this.store,
    DeviceIdentity? identity,
  }) : identity = identity ?? DeviceIdentity(store);
  final DeviceIdentity identity;

  final TronHttpClient http;
  final SecureStore store;

  Future<String?> lastUsername() => store.read(SecureStore.keyLastUsername);

  Future<String?> savedPassword() => store.read(SecureStore.keyOwnerPassword);
  Future<bool> remembersPassword() async =>
      await store.read(SecureStore.keyRememberPassword) == 'true' ||
      (await store.read(SecureStore.keyRememberPassword) == null &&
          await savedPassword() != null);

  Future<bool> hasStoredCookies() async {
    final raw = await store.read(SessionKey.owner.secureCookieKey);
    return raw != null && decodeCookies(raw).isNotEmpty;
  }

  /// xmulogin type=3: IDS form POST → OAuth code → token → TronClass session.
  Future<UserProfile> signIn({
    required String username,
    required String password,
    bool rememberPassword = false,
  }) async {
    try {
      await http.init();
      await http.clearSession();

      AppLog.event('login.step', fields: {'step': 'fetch_form'});
      final form = await _fetchLoginForm();
      final Uri next;
      try {
        next = await IdsAuth(http.hop).submit(
          url: form.url,
          html: form.html,
          username: username,
          password: password,
        );
      } on FormatException catch (error) {
        if (error.source == null &&
            const {
              '统一认证地址异常',
              '需要验证码，请在统一认证中完成登录',
              '统一认证页面异常',
              '统一认证未通过，请检查账号密码',
            }.contains(error.message)) {
          throw AuthException(error.message);
        }
        rethrow;
      }

      AppLog.event('login.step', fields: {'step': 'follow_code'});
      final code = await _followToAuthCode(next);
      AppLog.event('login.step', fields: {'step': 'oauth_token'});
      final profile = await completeOAuthCode(code);
      await store.write(SecureStore.keyLastUsername, username);
      await identity.bindStudentNumber(profile.studentNo ?? username);
      await store.write(SecureStore.keyRememberPassword, '$rememberPassword');
      if (rememberPassword) {
        await store.write(SecureStore.keyOwnerPassword, password);
      } else {
        await store.delete(SecureStore.keyOwnerPassword);
      }
      AppLog.event('login.step', fields: {'step': 'done', 'userId': profile.id});
      return profile;
    } catch (error) {
      throw _mapSignInError(error);
    }
  }

  AuthException _mapSignInError(Object error) {
    if (error is AuthException) return error;
    if (error is DioException) {
      final status = error.response?.statusCode ?? 0;
      if (status == 429) {
        return AuthException('登录请求过于频繁，请稍后重试');
      }
      if (status >= 500) {
        return AuthException('登录服务暂时不可用，请稍后重试');
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return AuthException('登录超时，请检查网络后重试');
      }
      if (error.type == DioExceptionType.connectionError) {
        return AuthException('网络连接失败，请检查网络后重试');
      }
      return AuthException('登录失败，请检查网络后重试');
    }
    return AuthException('登录失败，请稍后重试');
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
    final tokenRes = await http.postUri<Map<String, dynamic>>(
      TronEndpoints.tokenUri(),
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
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        return null;
      }
      rethrow;
    } on AuthException {
      return null;
    }
  }

  Future<UserProfile?> cachedProfile() async {
    final (rawId, displayName) = await (
      store.read(SecureStore.keyUserId),
      store.read(SecureStore.keyUserDisplayName),
    ).wait;
    final id = int.tryParse(rawId ?? '');
    if (id == null || id == 0) return null;
    return UserProfile(
      id: id,
      name: displayName ?? '用户',
    );
  }

  Future<UserProfile> fetchProfile() async {
    final res = await http.getUri<Map<String, dynamic>>(
      TronEndpoints.profile(),
    );
    final data = res.data;
    if (data == null) {
      throw AuthException('资料接口无数据');
    }
    final profile = UserProfile.fromJson(data);
    if (profile.id == 0) throw AuthException('资料接口返回无效账号');
    await store.write(SecureStore.keyUserDisplayName, profile.name);
    await store.write(SecureStore.keyUserId, '${profile.id}');
    if (profile.studentNo != null) {
      await identity.bindStudentNumber(profile.studentNo);
    }
    await http.persistCookies();
    return profile;
  }

  Future<void> signOut() async {
    final uid = int.tryParse(await store.read(SecureStore.keyUserId) ?? '');
    await http.clearSession();
    if (uid != null) await store.delete(AcademicSession.credentialKey(uid));
    await store.delete(SecureStore.keyOwnerPassword);
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
