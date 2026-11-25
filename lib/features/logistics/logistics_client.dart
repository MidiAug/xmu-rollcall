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
  Future<void>? _connecting;
  bool _writing = false;
  String? userName;
  String? userId;
  String? phone;
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
    RequestPriority priority = RequestPriority.background,
    ResponseType responseType = ResponseType.plain,
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
          responseType: responseType,
          contentType: contentType,
          validateStatus: (s) => s != null && s < 500,
          headers: {'User-Agent': TronEndpoints.userAgent, ...?headers},
        ),
      );
    }, priority: priority);
  }

  Future<void> connect({
    required String username,
    String? password,
    CookieJar? sso,
  }) => _connecting ??= _connect(
    username: username,
    password: password,
    sso: sso,
  ).whenComplete(() => _connecting = null);

  Future<void> _connect({
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
          userName = user['name'] as String?;
          userId = user['id'] as String?;
          phone = user['mobile'] as String?;
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
      throw const FormatException('后勤登录暂不可用，请重新登录所选账号');
    }
    throw const FormatException('后勤登录跳转过多');
  }

  Future<Object?> _api(
    String path,
    Object? data, {
    bool json = false,
    bool write = false,
  }) async {
    if (write && _writing) throw const FormatException('正在提交，请勿重复操作');
    if (write) _writing = true;
    try {
      final token = _token;
      final response = await _hop(
        data == null ? 'GET' : 'POST',
        origin.resolve('/api$path'),
        data: data,
        contentType: data == null
            ? null
            : data is FormData
            ? Headers.multipartFormDataContentType
            : json
            ? Headers.jsonContentType
            : Headers.formUrlEncodedContentType,
        priority: write
            ? RequestPriority.submission
            : RequestPriority.background,
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
      late Map<String, dynamic> body;
      try {
        body = logisticsDecode(response.data);
      } on FormatException {
        if (write) throw const LogisticsWriteUncertain();
        rethrow;
      }
      if (body['status'] != 'success' || body['errorCode'] != 0) {
        if (const {4010, 4011, 4012, 4013, 4014}.contains(body['errorCode'])) {
          _token = null;
        }
        final message = body['message'];
        throw FormatException(
          message is String && message.trim().isNotEmpty
              ? message
              : '后勤请求未通过，请更新后重试',
        );
      }
      return body['data'];
    } on DioException {
      if (write) throw const LogisticsWriteUncertain();
      rethrow;
    } finally {
      if (write) _writing = false;
    }
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
  Future<Map<String, dynamic>> messagePage(
    int page, {
    String status = '',
  }) async => _page(
    await _api('/manager/systemPersonalWait/listMessage', {
      'pageIndex': page,
      'pageSize': 20,
      'status': status,
    }),
  );
  Future<void> markMessageRead(String id) async {
    await _api('/manager/systemPersonalWait/statusMessage', {
      'status': 0,
      'id': id,
    }, write: true);
  }

  Future<Object?> areas() => _api('/repair/publish/getAreaTree', {});
  Future<Object?> projects(String area) =>
      _api('/repair/publish/getProjectByAreaId', {'areaId': area});
  Future<Object?> repairSettings() => _api('/repair/systemSetting/list', {});
  Future<Map<String, dynamic>> repairDetail(String id) async {
    final data = await _api('/repair/repairInfo/get', {'id': id});
    if (data is! Map<String, dynamic>) throw const FormatException('报修详情格式异常');
    return data;
  }

  Future<bool> canWithdraw(String id) async =>
      await _api('/repair/myRepair/ifAllowWithdrawMyRepair', {'id': id}) == 1;
  Future<void> withdraw(String id) async {
    if (!await canWithdraw(id)) {
      throw const FormatException('当前工单已不能撤销，请更新查看进度');
    }
    await _api('/repair/myRepair/withdrawMyRepair', {'id': id}, write: true);
    // The server owns eligibility and final status. Never optimistically remove it.
    await repairDetail(id);
  }

  Future<Map<String, dynamic>> repairRecipient(
    String area,
    String project,
  ) async {
    final data = await _api(
      '/repair/publish/getAcceptUserByAreaIdAndProjectId',
      {'areaId': area, 'projectId': project},
    );
    if (data is! Map<String, dynamic> || data['dept'] is! Map) {
      throw const FormatException('该维修项目尚未配置受理单位');
    }
    return data;
  }

  Future<String> submitRepair(Map<String, dynamic> form) async {
    final recipient = await repairRecipient(
      form['areaId'] as String,
      form['projectId'] as String,
    );
    await _api('/repair/oneNetPublish/checkIfHadProjectIdByAreaId', {
      'areaId': form['areaId'],
      'projectId': form['projectId'],
    });
    final result = await _api(
      '/repair/publish/publish',
      {
        ...form,
        'acceptDeptId': recipient['dept']['deptId'],
        'acceptDeptName': recipient['dept']['deptName'],
      },
      json: true,
      write: true,
    );
    if (result is! Map || result['id'] is! String) {
      throw const LogisticsWriteUncertain();
    }
    return result['id'] as String;
  }

  Future<Object?> evaluationFields() =>
      _api('/repair/commontProject/getProject', {});
  Future<Object?> evaluationLabels() =>
      _api('/repair/commontProject/getLabel', {});
  Future<void> evaluate(
    String id,
    List<Map<String, dynamic>> scores,
    String content,
    List<String> labels,
  ) async {
    final detail = await repairDetail(id);
    if ('${detail['status']}' != '4' || '${detail['ifCommont']}' != '0') {
      throw const FormatException('该工单当前无需评价，请更新查看');
    }
    await _api(
      '/repair/visitEvaluateUser/save',
      {
        'common': scores,
        'content': content,
        'repairId': id,
        'source': '0',
        'label': labels.join(','),
      },
      json: true,
      write: true,
    );
  }

  Future<Object?> feedbackScopes() =>
      _api('/supervise/systemServiceScope/getScopeTree', {'isShowNoDept': 0});
  Future<Object?> feedbackTypes() =>
      _api('/supervise/supervisionPost/queryServiceType', {});
  Future<Map<String, dynamic>> feedbackPosts(int page) async => _page(
    await _api('/supervise/oneNet/selectMyPublishPost', {
      'pageIndex': page,
      'pageSize': 20,
    }),
  );
  Future<Map<String, dynamic>> feedbackDetail(String id) async {
    final data = await _api('/supervise/oneNet/get', {
      'id': id,
      'schoolCode': '10384',
    });
    if (data is! Map<String, dynamic>) throw const FormatException('反馈详情格式异常');
    return data;
  }

  Future<Object?> feedbackReplies(String id) => _api(
    '/supervise/oneNet/replayList',
    {'postId': id, 'schoolCode': '10384', 'status': ''},
  );
  Future<String> submitFeedback(Map<String, dynamic> form) async {
    final result = await _api(
      '/supervise/supervisionPost/save',
      {
        ...form,
        'postUserId': userId,
        'postUserName': userName,
        'phone': logisticsEncrypt(
          form['phone'] as String,
          key: _clientKey,
          iv: _clientId,
        ),
      },
      json: true,
      write: true,
    );
    if (result is! Map || result['id'] is! String) {
      throw const LogisticsWriteUncertain();
    }
    return result['id'] as String;
  }

  Future<void> deleteFeedback(String id, String reason) async {
    await _api('/supervise/supervisionPost/deleteByIdByStudent', {
      'postId': id,
      'remark': reason,
    }, write: true);
  }

  Future<String> upload({
    required Stream<List<int>> Function() openRead,
    required int length,
    required String name,
  }) async {
    final data = await _api(
      '/file/upload',
      FormData.fromMap({
        'file': MultipartFile.fromStream(openRead, length, filename: name),
        'system': 'manager',
      }),
      write: true,
    );
    if (data is! Map || data['path'] is! String) {
      throw const FormatException('附件上传未完成');
    }
    return data['path'] as String;
  }

  Future<List<int>> attachment(Uri uri) async {
    if (uri.host != origin.host || !uri.path.startsWith('/fileupload/')) {
      throw const FormatException('附件地址异常');
    }
    final response = await _hop('GET', uri, responseType: ResponseType.bytes);
    if (response.statusCode != 200 || response.data is! List<int>) {
      throw const FormatException('附件未能读取');
    }
    return response.data as List<int>;
  }

  static Map<String, dynamic> _page(Object? data) {
    if (data is! Map<String, dynamic> ||
        data['rows'] is! List ||
        data['total'] is! num) {
      throw const FormatException('后勤列表格式异常');
    }
    return data;
  }
}

class LogisticsWriteUncertain extends FormatException {
  const LogisticsWriteUncertain() : super('未能确认提交结果，请先核对记录，避免重复提交');
}
