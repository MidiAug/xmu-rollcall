/// Stable endpoints and client profile for XMU TronClass.
abstract final class TronEndpoints {
  static const baseUrl = 'https://lnt.xmu.edu.cn';
  static const identityBase = 'https://c-identity.xmu.edu.cn';
  static const mobileCallback =
      'https://c-mobile.xmu.edu.cn/identity-web-login-callback?_h5=true';
  static const clientId = 'TronClassH5';

  static const apiVersionList = '1.1.0';
  static const apiVersionAnswer = '1.76';

  /// Align with xmulogin type=3 (mobile Chrome). One profile for login + API.
  static const userAgent =
      'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36';

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

  static const courseListPaths = <String>[
    '/api/my-courses?per_page=1000',
    '/api/courses?role=student&per_page=1000',
    '/api/courses?course_role=student&per_page=1000',
    '/api/my/courses?per_page=1000',
    '/api/courses?per_page=1000',
    '/api/courses',
  ];

  static Uri courseStudentRollcalls({
    required Object courseId,
    required Object studentId,
  }) =>
      Uri.parse(
        '$baseUrl/api/course/$courseId/student/$studentId/rollcalls',
      ).replace(queryParameters: {'page': '1', 'page_size': '100'});

  static Uri radarRollcalls() => Uri.parse(
        '$baseUrl/api/radar/rollcalls',
      ).replace(queryParameters: {'api_version': apiVersionList});

  static Uri studentRollcalls(int id) =>
      Uri.parse('$baseUrl/api/rollcall/$id/student_rollcalls');

  static Uri answerNumber(int id) =>
      Uri.parse('$baseUrl/api/rollcall/$id/answer_number_rollcall');

  static Uri answerRadar(int id) => Uri.parse(
        '$baseUrl/api/rollcall/$id/answer',
      ).replace(queryParameters: {'api_version': apiVersionAnswer});

  static Uri answerQr(int id) =>
      Uri.parse('$baseUrl/api/rollcall/$id/answer_qr_rollcall');

  static Uri todos() => Uri.parse('$baseUrl/api/todos');

  static Uri courseHomeworkActivities({
    required Object courseId,
    int page = 1,
    int pageSize = 100,
  }) =>
      Uri.parse('$baseUrl/api/courses/$courseId/homework-activities').replace(
        queryParameters: {
          'page': '$page',
          'page_size': '$pageSize',
        },
      );

  static Uri courseHomeworkDetail({
    required Object courseId,
    required Object activityId,
  }) =>
      Uri.parse(
        '$baseUrl/api/courses/$courseId/homework-activities/$activityId',
      );

  static Uri activityDetail(Object activityId) =>
      Uri.parse('$baseUrl/api/activities/$activityId');
}
