import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

class ResponseClient extends TronHttpClient {
  ResponseClient(this.payload) : super(store: SecureStore.memory());
  final Map<String, dynamic>? payload;
  @override
  Future<void> init() async {}
  @override
  Future<Response<T>> getUri<T>(
    Uri uri, {
    Options? options,
    CancelToken? cancelToken,
    RequestPriority priority = RequestPriority.normal,
  }) async => Response<T>(
    requestOptions: RequestOptions(path: uri.path),
    data: payload as T?,
    statusCode: 200,
  );
}

void main() {
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
