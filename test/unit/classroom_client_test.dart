import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/features/classrooms/classroom_client.dart';

class _Wire implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  String username = '20260000000001';
  Object? Function(RequestOptions)? reply;
  Completer<void>? hold;
  String? redirect;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls.add(o);
    if (o.uri.path == '/cas/login') {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            redirect ??
                'https://eclass.xmu.edu.cn/#/redirect?access_token=fixture-token',
          ],
        },
      );
    }
    if (o.uri.path == '/api/seatReservation/booking-orders' &&
        o.method == 'POST') {
      await hold?.future;
    }
    final value =
        reply?.call(o) ??
        switch (o.uri.path) {
          '/api/currentUser' => {
            'code': 0,
            'data': {
              'id': 'fixture-user',
              'code': username,
              'campus_ids': ['campus'],
            },
          },
          '/api/basic/campus' => {
            'total': 1,
            'count': 1,
            'data': [
              {'id': 'campus', 'name': '思明校区'},
            ],
          },
          '/api/basic/buildings' => {
            'total': 1,
            'count': 1,
            'data': [
              {'id': 'building', 'campus_id': 'campus', 'name': '测试楼'},
            ],
          },
          '/api/agendasList' => {'code': 0, 'data': []},
          '/api/customization/roomIntroduction' => {
            'total': 121,
            'count': 121,
            'data': [
              for (var i = 0; i < 120; i++)
                {
                  'room': {'id': 'room$i', 'room_name': '教室$i'},
                },
              {
                'room': {'id': 'room0', 'room_name': '教室0'},
              },
            ],
          },
          '/api/seatReservation/booking-orders' =>
            o.method == 'POST'
                ? {
                    'code': 0,
                    'data': {'order_id': 1},
                  }
                : {'current_page': 1, 'last_page': 2, 'data': []},
          _ => {'code': 0, 'data': []},
        };
    return ResponseBody.fromString(
      value is String ? value : jsonEncode(value),
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
  late ClassroomClient client;
  setUp(() {
    wire = _Wire();
    client = ClassroomClient(
      dio: Dio()..httpClientAdapter = wire,
      limiter: RateLimiter(minInterval: Duration.zero),
    );
  });
  tearDown(() => client.close());
  Future<void> connect() => client.connect(username: '20260000000001');
  test(
    'CAS callback token stays on school host and identity is verified',
    () async {
      await connect();
      expect(client.user!.code, '20260000000001');
      expect(wire.calls.map((v) => v.uri.path), [
        '/cas/login',
        '/api/currentUser',
      ]);
      expect(wire.calls.last.headers['Authorization'], 'Bearer fixture-token');
      await connect();
      expect(wire.calls, hasLength(2));
    },
  );
  test('mismatched identity and foreign redirects are rejected', () async {
    wire.username = 'different';
    await expectLater(connect(), throwsFormatException);
    expect(client.user, isNull);
    wire.username = '20260000000001';
    wire.redirect = 'https://example.com/?access_token=fixture';
    final n = wire.calls.length;
    await expectLater(connect(), throwsFormatException);
    expect(wire.calls.length, n + 1);
  });
  test(
    'batched home and room catalog deduplicate without per-room requests',
    () async {
      await connect();
      final h = await client.home();
      expect(h.campuses.single.name, '思明校区');
      final before = wire.calls.length;
      final rooms = await client.rooms();
      expect(rooms, hasLength(120));
      expect(wire.calls.length, before + 1);
      expect(wire.calls.last.uri.queryParameters['limit'], '10000');
    },
  );
  test('my bookings use own-record scope and explicit paging', () async {
    await connect();
    final page = await client.bookings(1);
    expect(page.nextPage, 2);
    expect(wire.calls.last.uri.queryParameters['my_record'], '1');
    expect(wire.calls.last.uri.queryParameters['per_page'], '20');
  });
  test(
    'seat submission has observed schema and rejects duplicate in-flight writes',
    () async {
      await connect();
      wire.hold = Completer<void>();
      final first = client.bookSeat('room', 7, '2026-12-01', '08:00', '08:30');
      while (!wire.calls.any((v) => v.method == 'POST')) {
        await Future<void>.delayed(Duration.zero);
      }
      await expectLater(
        client.bookSeat('room', 7, '2026-12-01', '08:00', '08:30'),
        throwsFormatException,
      );
      wire.hold!.complete();
      await first;
      final post = wire.calls.singleWhere((v) => v.method == 'POST');
      final data = post.data as Map;
      expect(data['seat_id'], 7);
      expect(data['book_time_list'], [
        {'start_time': '08:00', 'end_time': '08:30'},
      ]);
    },
  );
  test('malformed write response is uncertain and is not retried', () async {
    await connect();
    wire.reply = (o) => o.method == 'POST' ? '<html>timeout</html>' : null;
    await expectLater(
      client.bookSeat('room', 7, '2026-12-01', '08:00', '08:30'),
      throwsA(isA<ClassroomWriteUncertain>()),
    );
    expect(wire.calls.where((v) => v.method == 'POST'), hasLength(1));
  });
  test('identity guard blocks reads and writes before wire dispatch', () async {
    await connect();
    final count = wire.calls.length;
    client.identityGuard = () async => false;
    await expectLater(client.bookings(1), throwsStateError);
    await expectLater(client.cancelBooking(1), throwsStateError);
    expect(wire.calls.length, count);
  });
}
