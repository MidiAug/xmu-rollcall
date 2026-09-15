import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';

class AuthRepository {
  AuthRepository({
    required this.http,
    required this.store,
  });

  final TronHttpClient http;
  final SecureStore store;

  /// Exchange OAuth code → access_token → TronClass session.
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
      throw AuthException('未拿到 access_token，请重试登录');
    }

    await http.postUri<dynamic>(
      TronEndpoints.loginAccessToken(),
      data: {'access_token': accessToken, 'org_id': 1},
    );
    await http.persistCookies();
    return fetchProfile();
  }

  Future<UserProfile> importCookiesAndProbe(String cookieHeader) async {
    await http.importCookieHeader(cookieHeader);
    return fetchProfile();
  }

  Future<UserProfile?> tryRestoreSession() async {
    await http.init();
    try {
      return await fetchProfile();
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      if (code == 401 || code == 403 || code == 302) return null;
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
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
