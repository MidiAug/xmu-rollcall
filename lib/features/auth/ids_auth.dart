import 'package:dio/dio.dart';
import 'package:xmu_rollcall/features/auth/ids_password.dart';

typedef IdsHop =
    Future<Response<dynamic>> Function(
      String method,
      Uri uri, {
      Object? data,
      String? contentType,
    });

/// Shared IDS form submission. App-specific tickets and cookies stay with callers.
class IdsAuth {
  const IdsAuth(this.hop);
  final IdsHop hop;

  Future<Uri> submit({
    required Uri url,
    required String html,
    required String username,
    required String password,
  }) async {
    if (url.scheme != 'https' || url.host != 'ids.xmu.edu.cn') {
      throw const FormatException('统一认证地址异常');
    }
    if (idsFormLooksLikeCaptcha(html)) {
      throw const FormatException('需要验证码，请在统一认证中完成登录');
    }
    final fields = parseIdsLoginForm(html);
    if (fields == null) throw const FormatException('统一认证页面异常');
    final response = await hop(
      'POST',
      url,
      data: {
        'username': username,
        'password': encryptIdsPassword(password, fields.salt),
        'captcha': '',
        '_eventId': 'submit',
        'cllt': 'userNameLogin',
        'dllt': 'generalLogin',
        'lt': '',
        'execution': fields.execution,
      },
      contentType: Headers.formUrlEncodedContentType,
    );
    final location = response.headers.value('location');
    if (location == null || location.isEmpty) {
      throw FormatException(
        idsFormLooksLikeCaptcha('${response.data ?? ''}')
            ? '需要验证码，请在统一认证中完成登录'
            : '统一认证未通过，请检查账号密码',
      );
    }
    return url.resolve(location);
  }
}
