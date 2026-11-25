import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'lecture_models.dart';
export 'lecture_models.dart';

class LectureLoginRequired extends FormatException {
  const LectureLoginRequired() : super('请连接当前账号的信息学院讲座系统');
}

/// The observed school service is HTTP-only. IDS passwords and TronClass tokens
/// are never sent here. Its deviceKey belongs to this service and selected user.
class LectureClient {
  LectureClient({Dio? dio, RateLimiter? limiter})
    : dio = dio ?? Dio(),
      limiter = limiter ?? RateLimiter() {
    this.dio.options.connectTimeout = const Duration(seconds: 15);
    this.dio.options.receiveTimeout = const Duration(seconds: 25);
  }
  static final origin = Uri.parse('http://unify.xmu.edu.cn');
  static final authorizationEntry = origin.resolve('/r/RcR21D');
  final Dio dio;
  final RateLimiter limiter;
  Future<bool> Function()? identityGuard;
  String? _deviceKey, _username;
  Future<void> _guard() async {
    if (identityGuard != null && !await identityGuard!()) {
      throw StateError('账号已切换');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await limiter.schedule(() async {
      await _guard();
      return dio.postUri<dynamic>(
        origin.resolve('/api/$path'),
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (s) => s != null && s < 500,
          headers: {
            'User-Agent': TronEndpoints.userAgent,
            if (_deviceKey != null) 'Cookie': 'deviceKey=$_deviceKey',
          },
        ),
      );
    });
    await _guard();
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const LectureLoginRequired();
    }
    if (response.statusCode != 200) throw const FormatException('讲座系统暂时不可用');
    final v = lectureMap(response.data);
    if (v['success'] == false) {
      throw FormatException(
        lectureText(v['msg']).isEmpty ? '讲座查询未完成' : lectureText(v['msg']),
      );
    }
    if (v['success'] != true) throw const FormatException('讲座响应不完整');
    return v;
  }

  Future<void> connect({
    required String username,
    required String? deviceKey,
  }) async {
    if (_username != null && _username != username) {
      throw const FormatException('讲座会话身份不匹配');
    }
    if (_username == username && _deviceKey == deviceKey) return;
    if (deviceKey == null || deviceKey.isEmpty) {
      throw const LectureLoginRequired();
    }
    if (RegExp(r'[;\r\n]').hasMatch(deviceKey)) {
      throw const FormatException('讲座授权格式异常');
    }
    _deviceKey = deviceKey;
    try {
      final config = await _post('config/GetBasicConfig', {});
      final user = lectureMap(config['userInfo']);
      if (user['isLogined'] != true) throw const LectureLoginRequired();
      if (lectureText(user['userCode']) != username) {
        throw const FormatException('讲座授权与当前账号不一致，请切换账号后连接');
      }
      _username = username;
    } catch (_) {
      _deviceKey = null;
      _username = null;
      rethrow;
    }
  }

  Future<LecturePage> attended({int page = 1}) async {
    if (_username == null) throw const LectureLoginRequired();
    return LecturePage.fromJson(
      await _post('activity/MySignIn', {'page': page, 'pageSize': 20}),
    );
  }

  void close() => dio.close(force: true);
}
