import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_client_registry.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/session/session_credential_crypto.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/assist/assist_qr_batch.dart';
import 'package:xmu_rollcall/features/rollcall/qr_payload.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

class _RecordedCall {
  _RecordedCall({
    required this.method,
    required this.path,
    required this.cookie,
    required this.data,
  });

  final String method;
  final String path;
  final String? cookie;
  final Object? data;
}

/// Serves TronClass-shaped fixtures and records Cookie + body for assertions.
class _ChainAdapter implements HttpClientAdapter {
  final calls = <_RecordedCall>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final cookie = options.headers[HttpHeaders.cookieHeader]?.toString();
    calls.add(
      _RecordedCall(
        method: options.method,
        path: options.uri.path,
        cookie: cookie,
        data: options.data,
      ),
    );

    ResponseBody json(String body, [int status = 200]) =>
        ResponseBody.fromString(
          body,
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );

    final path = options.uri.path;
    final method = options.method;

    if (method == 'GET' && path.endsWith('/api/profile')) {
      if (cookie != null && cookie.contains('assist_tok=')) {
        return json(_fixture('profile_assist.json'));
      }
      if (cookie != null && cookie.contains('owner_tok=')) {
        return json('{"id":1,"name":"主号"}');
      }
      return json('{"message":"unauthorized"}', 401);
    }

    if (method == 'GET' &&
        (path.contains('/api/my-courses') || path.contains('/api/courses'))) {
      if (cookie != null && cookie.contains('assist_tok=')) {
        return json(_fixture('my_courses_assist.json'));
      }
      if (cookie != null && cookie.contains('other_tok=')) {
        return json(_fixture('my_courses_other.json'));
      }
      return json('{"courses":[{"id":501,"name":"高等数学A"}]}');
    }

    if (method == 'GET' && path.contains('radar/rollcalls')) {
      return json(_fixture('radar_rollcalls_qr.json'));
    }

    if (method == 'PUT' && path.contains('answer_qr_rollcall')) {
      final data = options.data as Map;
      expect(data['data'], isNotEmpty);
      expect(data['deviceId'], isNotEmpty);
      if (cookie == null || cookie.isEmpty) {
        return json('{"message":"no session"}', 401);
      }
      return json('{"status":"ok"}');
    }

    return json(
      jsonEncode({'message': 'unhandled', 'uri': '${options.uri}'}),
      404,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'fixture chain: discovery → same-course filter → export/import isolation → serial QR',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SecureStore.memory();
      final adapter = _ChainAdapter();

      final registry = SessionClientRegistry(
        store: store,
        createClient: ({
          required store,
          required sessionKey,
          required rateLimiter,
        }) {
          final dio = Dio()..httpClientAdapter = adapter;
          return TronHttpClient(
            store: store,
            sessionKey: sessionKey,
            rateLimiter: rateLimiter,
            cookieJar: CookieJar(),
            dio: dio,
          );
        },
      );

      final device = DeviceIdentity(store);
      await device.getId();

      // Owner discovers QR rollcall with course_id.
      final owner = registry.owner();
      await owner.init();
      await owner.importCookieHeader('owner_tok=OWNER');
      final ownerRepo = RollcallRepository(http: owner, identity: device);
      final active = await ownerRepo.fetchActive();
      expect(active, hasLength(1));
      expect(active.single.isQrcode, isTrue);
      expect(active.single.courseId, '501');

      // Assist A same course; Assist B other course.
      final assistA = registry.forKey(SessionKey.assist(1001));
      await assistA.init();
      await assistA.importCookieHeader('assist_tok=A');
      final coursesA =
          await RollcallRepository(http: assistA, identity: device)
              .fetchCourseIds();
      expect(coursesA, contains('501'));

      final assistB = registry.forKey(SessionKey.assist(2002));
      await assistB.init();
      await assistB.importCookieHeader('other_tok=B');
      final coursesB =
          await RollcallRepository(http: assistB, identity: device)
              .fetchCourseIds();
      expect(coursesB.contains('501'), isFalse);

      final eligible = filterAssistForCourse(
        courseId: active.single.courseId,
        identities: const [
          AssistIdentity(
            userId: 1001,
            displayName: '甲',
            kind: AssistCredentialKind.session,
          ),
          AssistIdentity(
            userId: 2002,
            displayName: '乙',
            kind: AssistCredentialKind.session,
          ),
        ],
        courseIdsByUser: {1001: coursesA, 2002: coursesB},
      );
      expect(eligible.map((e) => e.userId), [1001]);

      // Export assist cookies via temporary owner swap; restore owner after.
      final svc = AssistService(
        store: store,
        registry: registry,
        codec: AssistTokenCodec(),
        probeProfile: (client) async {
          final res = await client.getUri<Map<String, dynamic>>(
            Uri.parse('https://lnt.xmu.edu.cn/api/profile'),
          );
          final d = res.data!;
          return AssistProfileSnapshot(
            id: (d['id'] as num).toInt(),
            name: d['name'] as String,
          );
        },
      );

      final ownerBlob = await owner.exportCookiesJson();
      final assistBlob = await assistA.exportCookiesJson();
      expect(assistBlob, isNotNull);
      await owner.clearSession();
      await owner.importCookiesJson(assistBlob!);
      final sealed = await svc.exportOwnerPackage(
        kind: AssistExportKind.session,
        profileId: 1001,
        profileName: '甲',
        deviceId: 'assist-dev-1001',
      );
      await owner.clearSession();
      await owner.importCookiesJson(ownerBlob!);

      await registry.disposeAssist(1001);
      final imported = await svc.importToken(sealed);
      expect(imported.userId, 1001);
      expect(imported.displayName, '同学甲');
      expect(imported.deviceId, 'assist-dev-1001');

      final ownerCookies = await owner.cookieJar!
          .loadForRequest(Uri.parse('https://lnt.xmu.edu.cn'));
      expect(ownerCookies.any((c) => c.name == 'owner_tok'), isTrue);

      // Serial QR: owner then assist — different Cookie headers.
      adapter.calls.clear();
      final qrData = parseQrRollcallData(
        '{"data":"FAKE_QR_TOKEN_FOR_CONTRACT_TEST_XXXX"}',
      );
      final runner = AssistQrBatchRunner(
        submit: (target, data) async {
          final client = registry.forKey(target.key);
          await client.init();
          return RollcallRepository(http: client, identity: device).answerQr(
            rollcallId: 9001,
            data: data,
          );
        },
      );
      final results = await runner.run(
        qrData: qrData,
        targets: [
          const AssistQrTarget(key: SessionKey.owner, label: '我', userId: 1),
          AssistQrTarget(
            key: SessionKey.assist(1001),
            label: '甲',
            userId: 1001,
          ),
        ],
      );
      expect(results.every((r) => r.ok), isTrue);

      final qrCalls = adapter.calls
          .where((c) => c.path.contains('answer_qr_rollcall'))
          .toList();
      expect(qrCalls, hasLength(2));
      expect(qrCalls[0].cookie, contains('owner_tok'));
      expect(qrCalls[1].cookie, contains('assist_tok'));
      expect(qrCalls[0].cookie, isNot(equals(qrCalls[1].cookie)));

      // ignore: avoid_print
      print('[PASS] AC-ASSIST-03 isolation');
      // ignore: avoid_print
      print('[PASS] AC-ASSIST-05 same-course filter');
      // ignore: avoid_print
      print('[PASS] AC-ASSIST-06 serial QR dual session');
    },
  );
}
