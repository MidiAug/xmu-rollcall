import 'dart:convert';
import 'dart:typed_data';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:pointycastle/export.dart';
import 'package:uuid/uuid.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/features/auth/ids_auth.dart';

/// Public web-client wire codec, not an account credential. Matches the
/// school's account/js app and znbx/js/dencrypt.js (2026-11-25).
String logisticsEncrypt(String value, {String? key, String? iv}) {
  final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
    ..init(
      true,
      PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
        ParametersWithIV(
          KeyParameter(
            Uint8List.fromList(utf8.encode(key ?? '1974051005060708')),
          ),
          Uint8List.fromList(utf8.encode(iv ?? '1974051005060708')),
        ),
        null,
      ),
    );
  return base64Encode(cipher.process(Uint8List.fromList(utf8.encode(value))));
}

Map<String, dynamic> logisticsDecode(Object? value) {
  try {
    if (value is Map<String, dynamic>) return value;
    var text = '$value'.trim();
    if (text.startsWith('"')) text = jsonDecode(text) as String;
    if (!text.startsWith('{')) {
      final key = Uint8List.fromList(utf8.encode('1974051005060708'));
      final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
        ..init(
          false,
          PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
            ParametersWithIV(KeyParameter(key), key),
            null,
          ),
        );
      text = utf8.decode(cipher.process(base64Decode(text)));
    }
    return jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    throw const FormatException('后勤返回的数据无法读取');
  }
}

class LogisticsClient {
  LogisticsClient({Dio? dio, RateLimiter? limiter})
    : dio = dio ?? Dio(),
      limiter = limiter ?? RateLimiter() {
    this.dio.options.connectTimeout = const Duration(seconds: 20);
    this.dio.options.receiveTimeout = const Duration(seconds: 30);
    this.dio.interceptors.add(CookieManager(jar));
  }
  final Dio dio;
  final RateLimiter limiter;
  final CookieJar jar = CookieJar();
  Future<bool> Function()? identityGuard;
  String? _token;
  // Published in the official account/ihome JS bundle. Generated Token values
  // and the per-user TokenKey remain in memory and are never logged.
  static const _clientId = 'web201911chengdu';
  static const _clientKey = 'bf8ec0449942e7f4';
  static final origin = Uri.parse('https://xdhq.xmu.edu.cn');
  static final login = Uri.parse(
    'https://ids.xmu.edu.cn/authserver/login',
  ).replace(queryParameters: {'service': 'https://xdhq.xmu.edu.cn/cass/login'});

  Future<Response<dynamic>> _hop(
    String method,
    Uri uri, {
    Object? data,
    String? contentType,
    Map<String, dynamic>? headers,
  }) async {
    if (uri.scheme != 'https' ||
        !{'xdhq.xmu.edu.cn', 'ids.xmu.edu.cn'}.contains(uri.host)) {
      throw const FormatException('后勤登录地址异常');
    }
    return limiter.schedule(() async {
      if (identityGuard != null && !await identityGuard!()) {
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
    }, priority: RequestPriority.background);
  }

  Future<void> connect({
    required String username,
    String? password,
    CookieJar? sso,
  }) async {
    if (_token != null) return;
    if (sso != null) {
      await jar.saveFromResponse(login, await sso.loadForRequest(login));
    }
    var uri = login;
    var submitted = false;
    for (var i = 0; i < 16; i++) {
      if (uri.host == origin.host &&
          const {'/account/login', '/appAccount/login'}.contains(uri.path) &&
          uri.queryParameters.containsKey('userinfo')) {
        final result = await _api('/auth/login/auto', {
          'userInfo': uri.queryParameters['userinfo']!,
          'clientId': _clientId,
          'timestamp': logisticsEncrypt(
            '${DateTime.now().millisecondsSinceEpoch}',
          ),
          'schoolCode': '10384',
          'schoolName': '厦门大学',
        });
        if (result is! String || result.isEmpty) {
          throw const FormatException('后勤登录未完成');
        }
        _token = result;
        try {
          final user = await _api('/auth/user/info', null);
          if (user is! Map ||
              ![user['account'], user['unifiedAccount']].contains(username)) {
            throw const FormatException('后勤登录身份不匹配，请重新登录');
          }
        } catch (_) {
          _token = null;
          rethrow;
        }
        return;
      }
      final response = await _hop('GET', uri);
      final html = '${response.data ?? ''}';
      if (uri.host == login.host && html.contains('pwdEncryptSalt')) {
        if (submitted || password == null) {
          throw const FormatException('请重新登录所选账号以连接后勤');
        }
        submitted = true;
        uri = await IdsAuth(
          _hop,
        ).submit(url: uri, html: html, username: username, password: password);
        continue;
      }
      final location = response.headers.value('location');
      if (location != null &&
          {301, 302, 303, 307, 308}.contains(response.statusCode)) {
        uri = uri.resolve(location);
        continue;
      }
      throw const FormatException('后勤登录暂不可用，请打开官方页面重试');
    }
    throw const FormatException('后勤登录跳转过多');
  }

  Future<Object?> _api(String path, Map<String, dynamic>? data) async {
    final token = _token;
    final response = await _hop(
      data == null ? 'GET' : 'POST',
      origin.resolve('/api$path'),
      data: data,
      contentType: data == null ? null : Headers.formUrlEncodedContentType,
      headers: token == null
          ? null
          : {
              'TokenKey': token,
              'Token': logisticsEncrypt(
                jsonEncode({
                  'tokenKey': token,
                  'clientId': _clientId,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'GUID': const Uuid().v4(),
                }),
                key: _clientKey,
                iv: _clientId,
              ),
            },
    );
    if (response.statusCode != 200) {
      throw const FormatException('后勤服务暂不可用，请稍后重试');
    }
    final body = logisticsDecode(response.data);
    if (body['status'] != 'success' || body['errorCode'] != 0) {
      if (const {4010, 4011, 4012, 4013, 4014}.contains(body['errorCode'])) {
        _token = null;
      }
      throw const FormatException('后勤会话失效或请求未通过，请重新打开后重试');
    }
    return body['data'];
  }

  Future<Map<String, dynamic>> repairs(int page) async => _page(
    await _api('/repair/oneNetPublish/myList', {
      'pageNum': page,
      'pageSize': 20,
    }),
  );
  Future<Map<String, dynamic>> messages() async => _page(
    await _api('/manager/systemPersonalWait/listMessage', {
      'pageIndex': 1,
      'pageSize': 6,
    }),
  );
  static Map<String, dynamic> _page(Object? data) {
    if (data is! Map<String, dynamic> ||
        data['rows'] is! List ||
        data['total'] is! num) {
      throw const FormatException('后勤列表格式异常');
    }
    return data;
  }
}
