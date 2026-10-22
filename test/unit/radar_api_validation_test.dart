import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
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
