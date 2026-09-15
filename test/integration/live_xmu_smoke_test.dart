import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';

/// Optional live probes against XMU TronClass.
///
/// Enable:
///   $env:LIVE_XMU="1"
/// Optional cookie for profile:
///   $env:LIVE_XMU_COOKIE="session=...; ..."
void main() {
  final live = Platform.environment['LIVE_XMU'] == '1';
  final cookie = Platform.environment['LIVE_XMU_COOKIE'];

  test(
    'live smoke: TLS reach lnt.xmu.edu.cn',
    () async {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (_) => true,
          headers: {'User-Agent': TronEndpoints.userAgent},
        ),
      );
      final res = await dio.getUri(Uri.parse('${TronEndpoints.baseUrl}/'));
      // Any HTTP status proves DNS+TLS+reachability (login wall / 200 / 302).
      expect(res.statusCode, isNotNull);
      expect(res.statusCode!, greaterThanOrEqualTo(200));
      expect(res.statusCode!, lessThan(600));
      // ignore: avoid_print
      print('[PASS] live smoke status=${res.statusCode}');
    },
    skip: live ? false : 'Set LIVE_XMU=1 to hit real network',
  );

  test(
    'live profile with cookie (optional)',
    () async {
      expect(cookie, isNotNull, reason: 'LIVE_XMU_COOKIE required');
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (_) => true,
          headers: {
            'User-Agent': TronEndpoints.userAgent,
            'Accept': 'application/json',
            'Cookie': cookie!,
          },
        ),
      );
      final res = await dio.getUri(TronEndpoints.profile());
      expect(res.statusCode, anyOf(200, 401, 403));
      if (res.statusCode == 200) {
        final data = res.data;
        expect(data, isA<Map>());
        final map = Map<String, dynamic>.from(data as Map);
        expect(map['id'], isNotNull);
        // ignore: avoid_print
        print('[PASS] live profile id=${map['id']} name=${map['name']}');
      } else {
        // ignore: avoid_print
        print(
          '[INFO] cookie rejected status=${res.statusCode} — refresh LIVE_XMU_COOKIE',
        );
      }
    },
    skip: live && cookie != null && cookie!.isNotEmpty
        ? false
        : 'Need LIVE_XMU=1 and LIVE_XMU_COOKIE',
  );
}
