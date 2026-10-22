import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

class _Adapter implements HttpClientAdapter {
  Object? detail = {
    'course_id': 42,
    'rollcall_time': '2026-10-15T00:05:00+08:00',
  };
  Object? timetable = {
    'rollcalls': [
      {'id': 8, 'number_code': '9999'},
      {'id': '7', 'number_code': '0042'},
    ],
  };
  int detailStatus = 200;
  int timetableStatus = 200;
  void Function()? afterDetail;
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    expect(options.method, 'GET');
    final path = options.uri.path;
    expect(path, isIn(['/api/rollcall/7', '/api/timetable_rollcalls']));
    final isDetail = path == '/api/rollcall/7';
    if (isDetail) afterDetail?.call();
    return ResponseBody.fromString(
      jsonEncode(isDetail ? detail : timetable),
      isDetail ? detailStatus : timetableStatus,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late _Adapter adapter;
  late RollcallRepository repo;

  setUp(() {
    adapter = _Adapter();
    final store = SecureStore.memory();
    final dio = Dio()..httpClientAdapter = adapter;
    dio.options.headers['Cookie'] = 'session=test-session';
    repo = RollcallRepository(
      http: TronHttpClient(
        store: store,
        dio: dio,
        rateLimiter: RateLimiter(minInterval: Duration.zero),
      ),
      identity: DeviceIdentity(store),
    );
  });

  test(
    'uses UTC date, same session, exact rollcall and leading zeros',
    () async {
      expect(await repo.fetchNumberCode(7), '0042');
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.last.uri.queryParameters, {
        'course_ids': '42',
        'rollcall_date': '2026-10-14',
      });
      for (final request in adapter.requests) {
        expect(request.uri.host, 'lnt.xmu.edu.cn');
        expect(request.headers['Cookie'], 'session=test-session');
      }
    },
  );

  test('Z and offset timestamps resolve to the same UTC date', () async {
    for (final timestamp in [
      '2026-10-14T23:54:31Z',
      '2026-10-15T07:54:31+08:00',
      '2026-10-14T18:54:31-05:00',
    ]) {
      adapter.detail = {'course_id': '42', 'rollcall_time': timestamp};
      expect(await repo.fetchNumberCode(7), '0042');
      expect(
        adapter.requests.last.uri.queryParameters['rollcall_date'],
        '2026-10-14',
      );
    }
  });

  test('missing or empty target code never reads a different record', () async {
    for (final rows in [
      [],
      [
        {'id': 8, 'number_code': '9999'},
      ],
      [
        {'id': 7, 'number_code': null},
        {'id': 8, 'number_code': '9999'},
      ],
      [
        {'id': 7, 'number_code': '  '},
      ],
      [
        {
          'id': 7,
          'number_code': {'number_code': '9999'},
        },
      ],
      [
        null,
        {'id': 8, 'number_code': '9999'},
      ],
    ]) {
      adapter.timetable = {'rollcalls': rows};
      expect(await repo.fetchNumberCode(7), isNull);
    }
  });

  test('invalid detail fails before querying timetable', () async {
    for (final detail in [
      null,
      [],
      {},
      {'course_id': 42, 'rollcall_time': 'invalid'},
      {'course_id': 42, 'rollcall_time': '2026-10-15T07:54:31'},
      {'course_id': 0, 'rollcall_time': '2026-10-14T23:54:31Z'},
    ]) {
      adapter.requests.clear();
      adapter.detail = detail;
      await expectLater(repo.fetchNumberCode(7), throwsFormatException);
      expect(adapter.requests, hasLength(1));
    }
  });

  test('malformed timetable is a protocol error', () async {
    for (final data in [
      null,
      [],
      {},
      {'rollcalls': 'invalid'},
    ]) {
      adapter.timetable = data;
      await expectLater(repo.fetchNumberCode(7), throwsFormatException);
    }
  });

  test(
    'authorization and server failures propagate without submission',
    () async {
      for (final status in [401, 403, 429, 503]) {
        adapter.requests.clear();
        adapter.detailStatus = status;
        await expectLater(
          repo.fetchNumberCode(7),
          throwsA(isA<DioException>()),
        );
        expect(adapter.requests, hasLength(1));

        adapter.detailStatus = 200;
        adapter.timetableStatus = status;
        await expectLater(
          repo.fetchNumberCode(7),
          throwsA(isA<DioException>()),
        );
        adapter.timetableStatus = 200;
      }
    },
  );

  test('cancellation after detail prevents the timetable request', () async {
    final token = CancelToken();
    adapter.afterDetail = () => token.cancel('superseded');
    await expectLater(
      repo.fetchNumberCode(7, cancelToken: token),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('no code keeps active item available for manual entry', () async {
    adapter.timetable = {'rollcalls': []};
    final item = RollcallItem.fromJson({'rollcall_id': 7, 'is_number': true});
    final result = await repo.enrichActive([item]);
    expect(result.single.rollcallId, 7);
    expect(result.single.numberCode, isNull);
    expect(result.single.numberCodeError, contains('手动输入'));
  });
}
