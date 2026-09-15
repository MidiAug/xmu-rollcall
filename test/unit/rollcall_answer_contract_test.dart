import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

class _MemStore extends SecureStore {
  final Map<String, String> _m = {};

  @override
  Future<String?> read(String key) async => _m[key];

  @override
  Future<void> write(String key, String value) async => _m[key] = value;

  @override
  Future<void> delete(String key) async => _m.remove(key);

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    for (final k in keys) {
      _m.remove(k);
    }
  }
}

class _Adapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PUT' &&
        options.path.contains('answer_number_rollcall')) {
      final data = options.data as Map;
      expect(data['deviceId'], isNotEmpty);
      expect(data['numberCode'], '0042');
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.method == 'PUT' && options.path.contains('/answer')) {
      final data = options.data as Map;
      expect(data['latitude'], 24.4);
      expect(data['longitude'], 118.1);
      expect(data['deviceId'], isNotEmpty);
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('{}', 404);
  }
}

void main() {
  test('answerNumber and answerRadar contract payloads', () async {
    final store = _MemStore();
    final dio = Dio()..httpClientAdapter = _Adapter();
    final http = TronHttpClient(store: store, dio: dio);
    // Skip PersistCookieJar init — mark ready via direct use of putUri after fake init.
    // putUri does not require _ready; only CookieManager needs init.
    // Call putUri through repository which calls http.init — that needs path_provider.
    // Instead exercise repository methods by temporarily not calling init:
    final identity = DeviceIdentity(store);
    await identity.getId();

    // Bypass init by using putUri which uses limiter+dio only.
    final repo = RollcallRepository(http: http, identity: identity);

    // Manually set ready path: init uses path_provider — in unit test we call
    // answer via http.putUri after forcing _ready is private.
    // Use dio directly through a thin path: call repository after stubbing init.
    // Simplest: invoke putUri on client without init (CookieManager not added yet — OK).
    final number = await repo.answerNumber(rollcallId: 1, numberCode: '0042');
    expect(number.ok, isTrue);

    final radar = await repo.answerRadar(
      rollcallId: 2,
      latitude: 24.4,
      longitude: 118.1,
      accuracy: 20,
    );
    expect(radar.ok, isTrue);

    final id1 = await identity.getId();
    final id2 = await identity.getId();
    expect(id1, id2);
  });
}
