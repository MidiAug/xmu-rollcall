import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';

class ResponseClient extends TronHttpClient {
  ResponseClient(this.payload) : super(store: SecureStore.memory());
  final Map<String, dynamic>? payload;
  int requests = 0;
  @override
  Future<void> init() async {}
  @override
  Future<Response<T>> getUri<T>(
    Uri uri, {
    Options? options,
    CancelToken? cancelToken,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    requests++;
    return Response<T>(
      requestOptions: RequestOptions(path: uri.path),
      data: payload as T?,
      statusCode: 200,
    );
  }
}

void main() {
  test(
    'repository gate prevents every active-list HTTP request outside the window',
    () async {
      final client = ResponseClient({'rollcalls': []});
      var now = DateTime(2026, 10, 24, 7, 29);
      final repo = RollcallRepository(
        http: client,
        identity: DeviceIdentity(SecureStore.memory()),
        loadDetectionWindow: () async => const DetectionWindow(enabled: true),
        discoveryClock: () => now,
      );
      await expectLater(
        repo.fetchActive(),
        throwsA(isA<DetectionWindowClosed>()),
      );
      expect(client.requests, 0);
      now = DateTime(2026, 10, 24, 7, 30);
      expect(await repo.fetchActive(), isEmpty);
      expect(client.requests, 1);
      now = DateTime(2026, 10, 24, 22);
      await expectLater(
        repo.fetchActiveEnriched(),
        throwsA(isA<DetectionWindowClosed>()),
      );
      expect(client.requests, 1);
    },
  );
  RollcallRepository repo(Map<String, dynamic>? payload) => RollcallRepository(
    http: ResponseClient(payload),
    identity: DeviceIdentity(SecureStore.memory()),
  );
  test('valid empty list is successful', () async {
    expect(await repo({'rollcalls': []}).fetchActive(), isEmpty);
  });
  test('missing payload is not a successful empty result', () async {
    await expectLater(repo(null).fetchActive(), throwsFormatException);
  });
  test('changed response shape is a protocol failure', () async {
    await expectLater(repo({'data': []}).fetchActive(), throwsFormatException);
    await expectLater(
      repo({'rollcalls': 'login required'}).fetchActive(),
      throwsFormatException,
    );
    await expectLater(
      repo({
        'rollcalls': [null],
      }).fetchActive(),
      throwsFormatException,
    );
  });
}
