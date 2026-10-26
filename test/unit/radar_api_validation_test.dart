import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

class _RadarAdapter implements HttpClientAdapter {
  int status = 200;
  Object body = {'ok': true};
  int requests = 0;
  RequestOptions? last;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late _RadarAdapter adapter;
  late RollcallRepository repo;
  setUp(() {
    adapter = _RadarAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    repo = RollcallRepository(
      identity: DeviceIdentity(SecureStore.memory()),
      http: TronHttpClient(store: SecureStore.memory(), dio: dio),
    );
  });
  test(
    'radar guard executes after the real HTTP queue and can prevent transport',
    () async {
      final gate = Completer<void>();
      final entered = Completer<void>();
      final limiter = RateLimiter(maxConcurrent: 1, minInterval: Duration.zero);
      final blocking = limiter.schedule(() async {
        entered.complete();
        await gate.future;
      });
      await entered.future;
      final memory = SecureStore.memory();
      final dio = Dio()..httpClientAdapter = adapter;
      final guarded = RollcallRepository(
        identity: DeviceIdentity(memory),
        http: TronHttpClient(store: memory, dio: dio, rateLimiter: limiter),
      );
      var guardCalls = 0;
      final queued = guarded.answerRadar(
        rollcallId: 7,
        latitude: 24.5,
        longitude: 118.2,
        beforeSend: () async {
          guardCalls++;
          throw StateError('Stopped or changed');
        },
      );
      final result = expectLater(queued, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(guardCalls, 0);
      expect(adapter.requests, 0);
      gate.complete();
      await blocking;
      await result;
      expect(guardCalls, 1);
      expect(adapter.requests, 0);
    },
  );
  test(
    'radar retains actual accuracy, coordinate order and stable device ID',
    () async {
      await repo.answerRadar(
        rollcallId: 7,
        latitude: 24.4,
        longitude: 118.1,
        accuracy: 850,
      );
      final first = adapter.last!.data as Map;
      expect(adapter.last!.uri.path, '/api/rollcall/7/answer');
      expect(adapter.last!.method, 'PUT');
      expect(first['accuracy'], 850);
      expect(first['latitude'], 24.4);
      expect(first['longitude'], 118.1);
      await repo.answerRadar(rollcallId: 7, latitude: 24.4, longitude: 118.1);
      expect((adapter.last!.data as Map)['deviceId'], first['deviceId']);
    },
  );
  test('invalid coordinates and precision never send a request', () async {
    for (final args in [
      [double.nan, 118.1, 35.0],
      [91.0, 118.1, 35.0],
      [24.4, 181.0, 35.0],
      [24.4, 118.1, 0.0],
      [24.4, 118.1, double.infinity],
    ]) {
      await expectLater(
        repo.answerRadar(
          rollcallId: 7,
          latitude: args[0],
          longitude: args[1],
          accuracy: args[2],
        ),
        throwsArgumentError,
      );
    }
    expect(adapter.requests, 0);
  });
  test('out-of-range business response keeps server distance', () async {
    adapter.status = 400;
    adapter.body = {'distance': 321, 'message': 'outside'};
    final result = await repo.answerRadar(
      rollcallId: 7,
      latitude: 24.4,
      longitude: 118.1,
    );
    expect(result.ok, isFalse);
    expect(result.status, 400);
    expect(result.message, contains('321'));
    expect(adapter.requests, 1);
  });
  test(
    'current rejection without distance preserves message without fabricating meters',
    () async {
      adapter.status = 400;
      adapter.body = {'message': '不在签到范围内'};
      final result = await repo.answerRadar(
        rollcallId: 7,
        latitude: 24.4,
        longitude: 118.1,
      );
      expect(result.ok, isFalse);
      expect(result.message, '不在签到范围内');
      expect(adapter.requests, 1);
      adapter.body = {};
      final empty = await repo.answerRadar(
        rollcallId: 7,
        latitude: 24.4,
        longitude: 118.1,
      );
      expect(empty.ok, isFalse);
      expect(empty.message, '提交失败 (400)');
      expect(empty.raw.containsKey('distance'), isFalse);
    },
  );
  test(
    'authentication and throttling still propagate as HTTP errors',
    () async {
      for (final status in [401, 403, 429, 500]) {
        adapter.status = status;
        adapter.body = {'message': 'rejected'};
        await expectLater(
          repo.answerRadar(rollcallId: 7, latitude: 24.4, longitude: 118.1),
          throwsA(
            isA<DioException>().having(
              (e) => e.response?.statusCode,
              'status',
              status,
            ),
          ),
        );
      }
    },
  );
}
