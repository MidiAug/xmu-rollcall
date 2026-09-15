/// Stable endpoints and client profile for XMU TronClass.
abstract final class TronEndpoints {
  static const baseUrl = 'https://lnt.xmu.edu.cn';
  static const identityBase = 'https://c-identity.xmu.edu.cn';
  static const mobileCallback =
      'https://c-mobile.xmu.edu.cn/identity-web-login-callback?_h5=true';
  static const clientId = 'TronClassH5';

  static const apiVersionList = '1.1.0';
  static const apiVersionAnswer = '1.76';

  /// Self-describing UA (KB-01): one profile for the whole app.
  static const userAgent =
      'xmu-rollcall/0.1.0 (Flutter; XMU TronClass client)';

  static Uri oauthAuthorizeUri() {
    return Uri.parse(
      '$identityBase/auth/realms/xmu/protocol/openid-connect/auth',
    ).replace(
      queryParameters: {
        'scope': 'openid',
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': mobileCallback,
      },
    );
  }

  static Uri tokenUri() =>
      Uri.parse('$identityBase/auth/realms/xmu/protocol/openid-connect/token');

  static Uri loginAccessToken() =>
      Uri.parse('$baseUrl/api/login?login=access_token');

  static Uri profile() => Uri.parse('$baseUrl/api/profile');

  static Uri radarRollcalls() => Uri.parse(
        '$baseUrl/api/radar/rollcalls',
      ).replace(queryParameters: {'api_version': apiVersionList});

  static Uri answerNumber(int id) =>
      Uri.parse('$baseUrl/api/rollcall/$id/answer_number_rollcall');

  static Uri answerRadar(int id) => Uri.parse(
        '$baseUrl/api/rollcall/$id/answer',
      ).replace(queryParameters: {'api_version': apiVersionAnswer});
}
