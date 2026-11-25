import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/features/lectures/lecture_client.dart';
import '../fixtures/lecture_fixture.dart';

class _Wire implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  String user = 'fixture-student';
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls.add(o);
    final value = o.uri.path.endsWith('/GetBasicConfig')
        ? {
            'success': true,
            'userInfo': {'isLogined': true, 'userCode': user},
          }
        : {
            'success': true,
            'page': 2,
            'pageSize': 20,
            'totalRow': 45,
            'successCount': 15,
            'data': [
              lectureFixture(),
              {
                ...lectureFixture(),
                'ActivityCategoryId': 'fixture-lecture',
                'Serial': 'other-session',
                'Code': 'private-student',
                'RealName': 'private-name',
                'Mobile': 'private-mobile',
              },
            ],
          };
    return ResponseBody.fromString(
      jsonEncode(value),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Wire wire;
  late LectureClient client;
  setUp(() {
    wire = _Wire();
    client = LectureClient(
      dio: Dio()..httpClientAdapter = wire,
      limiter: RateLimiter(minInterval: Duration.zero, maxPerMinute: 100),
    );
  });
  tearDown(() => client.close());
  Future<void> connect() =>
      client.connect(username: 'fixture-student', deviceKey: 'fixture-session');
  test('binds verified school user and requests only one list page', () async {
    await connect();
    final page = await client.attended(page: 2);
    expect(page.nextPage, 3);
    expect(page.successCount, 15);
    expect(page.rows.map((r) => r.key).toSet(), hasLength(2));
    expect(wire.calls.map((o) => o.uri.path), [
      '/api/config/GetBasicConfig',
      '/api/activity/MySignIn',
    ]);
    expect(wire.calls.last.data, {'page': 2, 'pageSize': 20});
    expect(wire.calls.last.headers['Cookie'], 'deviceKey=fixture-session');
    expect(jsonEncode(page.toJson()), isNot(contains('private-name')));
    expect(jsonEncode(page.toJson()), isNot(contains('private-mobile')));
  });
  test(
    'rejects a different account before reading any personal records',
    () async {
      wire.user = 'other-student';
      await expectLater(connect(), throwsFormatException);
      await expectLater(
        client.attended(),
        throwsA(isA<LectureLoginRequired>()),
      );
      expect(wire.calls, hasLength(1));
    },
  );
  test(
    'no session does not try an IDS password or anonymous personal query',
    () async {
      await expectLater(
        client.connect(username: 'fixture-student', deviceKey: null),
        throwsA(isA<LectureLoginRequired>()),
      );
      expect(wire.calls, isEmpty);
    },
  );
  test(
    'validates record response without a missing list being treated as empty',
    () {
      expect(
        () => LecturePage.fromJson({'data': {}, 'page': 1, 'pageSize': 20}),
        throwsFormatException,
      );
    },
  );
}
