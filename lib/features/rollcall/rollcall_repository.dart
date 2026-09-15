import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

class RollcallRepository {
  RollcallRepository({
    required this.http,
    required this.identity,
  });

  final TronHttpClient http;
  final DeviceIdentity identity;

  Future<List<RollcallItem>> fetchActive() async {
    await http.init();
    final res = await http.getUri<Map<String, dynamic>>(
      TronEndpoints.radarRollcalls(),
    );
    final data = res.data ?? const {};
    final rawList = data['rollcalls'];
    if (rawList is! List) return const [];
    return rawList
        .whereType<Map>()
        .map((e) => RollcallItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AnswerResult> answerNumber({
    required int rollcallId,
    required String numberCode,
  }) async {
    final deviceId = await identity.getId();
    final res = await http.putUri<dynamic>(
      TronEndpoints.answerNumber(rollcallId),
      data: {
        'deviceId': deviceId,
        'numberCode': numberCode,
      },
    );
    return _mapAnswer(res);
  }

  Future<AnswerResult> answerRadar({
    required int rollcallId,
    required double latitude,
    required double longitude,
    double accuracy = 35,
  }) async {
    final deviceId = await identity.getId();
    final res = await http.putUri<dynamic>(
      TronEndpoints.answerRadar(rollcallId),
      data: {
        'accuracy': accuracy,
        'altitude': 0,
        'altitudeAccuracy': null,
        'deviceId': deviceId,
        'heading': null,
        'latitude': latitude,
        'longitude': longitude,
        'speed': null,
      },
    );
    return _mapAnswer(res);
  }

  AnswerResult _mapAnswer(Response<dynamic> res) {
    final status = res.statusCode ?? 0;
    final data = res.data;
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{'raw': data};
    if (status >= 200 && status < 300) {
      return AnswerResult(ok: true, message: '提交成功', raw: map);
    }
    final distance = map['distance'];
    final msg = distance != null
        ? '未成功，距离约 $distance'
        : (map['message']?.toString() ?? '提交失败 ($status)');
    return AnswerResult(ok: false, message: msg, raw: map);
  }
}
