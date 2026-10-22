import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

class _Adapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'rollcalls': [
        {'id': 1, 'status': 'not_signed'},
        {'id': 2, 'status': 'unsigned'},
        {'id': 3, 'status': 'on_call_fine'},
        {'id': 4, 'status': 'absent'},
        {'id': 5, 'status': 'excused'},
        {'id': 6, 'status': 'on_call', 'student_status': 'signed'},
      ],
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  test(
    'negative platform statuses cannot match signed as a substring',
    () async {
      final store = SecureStore.memory();
      final dio = Dio()..httpClientAdapter = _Adapter();
      dio.options.headers['Cookie'] = 'session=test';
      final repo = RollcallRepository(
        http: TronHttpClient(
          store: store,
          dio: dio,
          cookieJar: CookieJar(),
          rateLimiter: RateLimiter(minInterval: Duration.zero),
        ),
        identity: DeviceIdentity(store),
      );
      final rows = await repo.fetchCourseRollcalls(courseId: 'a', studentId: 1);
      expect(
        {for (final r in rows) r.rollcallId: r.signedStatus},
        {'1': '未签到', '2': '未签到', '3': '已签到', '4': '未签到', '5': '未知', '6': '已签到'},
      );
    },
  );
}
