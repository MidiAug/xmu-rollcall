import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/auth/ids_auth.dart';
import 'package:xmu_rollcall/features/schedule/academic_client.dart';

const form =
    '<input id="pwdEncryptSalt" value="1234567890123456">'
    '<input name="execution" value="test-execution"><script>var needCaptcha = "";</script>';

class _PendingClient extends AcademicClient {
  _PendingClient(SecureStore store, this.result) : super(store: store);
  final Future<AcademicSchedule> Function() result;
  int calls = 0;
  @override
  Future<AcademicSchedule> fetch(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    DateTime? at,
  }) {
    calls++;
    return result();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'shared IDS encrypts password and refuses captcha before submission',
    () async {
      var posts = 0;
      final auth = IdsAuth((method, uri, {data, contentType}) async {
        posts++;
        expect(method, 'POST');
        expect((data as Map)['password'], isNot('fake-password'));
        expect(data['execution'], 'test-execution');
        return Response(
          requestOptions: RequestOptions(path: uri.toString()),
          statusCode: 302,
          headers: Headers.fromMap({
            'location': ['https://jw.xmu.edu.cn/login?ticket=fake-ticket'],
          }),
        );
      });
      await auth.submit(
        url: Uri.parse('https://ids.xmu.edu.cn/authserver/login'),
        html: form,
        username: 'fake-student',
        password: 'fake-password',
      );
      expect(posts, 1);
      await expectLater(
        auth.submit(
          url: Uri.parse('https://ids.xmu.edu.cn/authserver/login'),
          html: form.replaceFirst('needCaptcha = ""', 'needCaptcha = "true"'),
          username: 'fake-student',
          password: 'fake-password',
        ),
        throwsFormatException,
      );
      expect(posts, 1);
    },
  );
  test(
    'complete isolated CAS chain initializes app and fetches full term without ZC',
    () async {
      final store = SecureStore.memory({SecureStore.keyUserId: '7'});
      final requests = <RequestOptions>[];
      var appEntries = 0;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, handler) {
            requests.add(r);
            var status = 200;
            Object body = {};
            Map<String, List<String>> headers = {};
            switch (r.uri.path) {
              case '/appShow':
                status = ++appEntries == 1 ? 404 : 200;
                body = '<html>academic application</html>';
              case '/authserver/login':
                if (r.method == 'POST') {
                  expect((r.data as Map)['password'], isNot('fake-password'));
                  status = 302;
                  headers = {
                    'location': ['https://jw.xmu.edu.cn/login?ticket=fake'],
                  };
                } else {
                  body = form;
                }
              case '/login':
                status = 302;
                headers = {
                  'location': ['/new/index.html'],
                  'set-cookie': ['TEST_JW=fake; Path=/; Secure'],
                };
              case '/new/index.html':
                body = '<html>academic portal</html>';
              case '/gsapp/sys/wdkbapp/wdkcb/initXsxx.do':
                expect(r.method, 'GET');
                body = {
                  'success': true,
                  'data': [
                    {'XH': 'fake-student'},
                  ],
                };
              case '/gsapp/sys/wdkbapp/modules/xskcb/kfdxnxqcx.do':
                body = {
                  'datas': {
                    'kfdxnxqcx': {
                      'rows': [
                        {'XNXQDM': '20261'},
                        {'XNXQDM': '20262'},
                      ],
                    },
                  },
                };
              case '/gsapp/sys/wdkbapp/wdkcb/getZcxx.do':
                body = {'success': true, 'currentZc': '8'};
              case '/gsapp/sys/wdkbapp/wdkcb/queryXsskjc.do':
                body = {
                  'data': [
                    {'DM': '3', 'KSSJ': 1010, 'JSSJ': 1055},
                    {'DM': '4', 'KSSJ': '11:05', 'JSSJ': '11:50'},
                  ],
                };
              case '/gsapp/sys/wdkbapp/wdkcb/queryXspkjg.do':
                expect((r.data as Map).containsKey('ZC'), isFalse);
                expect(r.data['XH'], 'fake-student');
                body = {
                  'success': true,
                  'pkjgList': [
                    {
                      'XH': 'must-not-persist',
                      'KCDM': 'CS1',
                      'KCMC': '测试课',
                      'BJDM': '1',
                      'XQ': '1',
                      'ZCBH': '1111111111111111',
                      'KSJCDM': '3',
                      'JSJCDM': '4',
                      'JASMC': 'A101',
                    },
                  ],
                  'ttbList': [],
                };
              default:
                fail('unexpected endpoint ${r.uri.path}');
            }
            handler.resolve(
              Response(
                requestOptions: r,
                statusCode: status,
                headers: Headers.fromMap(headers),
                data: body is String ? body : jsonEncode(body),
              ),
            );
          },
        ),
      );
      final client = AcademicClient(
        store: store,
        dio: dio,
        limiter: RateLimiter(minInterval: Duration.zero, maxPerMinute: 100),
      );
      final result = await client.fetch(
        7,
        username: 'fake-student',
        password: 'fake-password',
        at: DateTime(2026, 10, 27),
      );
      expect(result.monday, DateTime(2026, 9, 7));
      expect(result.rows.single.containsKey('XH'), isFalse);
      expect(
        requests.where(
          (r) => r.uri.host == 'ids.xmu.edu.cn' && r.method == 'POST',
        ),
        hasLength(1),
      );
      expect(requests.every((r) => r.uri.host != 'lnt.xmu.edu.cn'), isTrue);
      expect(await store.read(AcademicClient.credentialKey(7)), isNotNull);
      expect(await store.read(SecureStore.keySessionCookies), isNull);
    },
  );
  test(
    'non-campus redirects are rejected before sending any credential',
    () async {
      final client = AcademicClient(store: SecureStore.memory());
      await expectLater(
        client.open(
          Uri.parse('https://example.org/login'),
          username: 'fake',
          password: 'fake',
        ),
        throwsFormatException,
      );
      client.dio.close();
    },
  );
  test(
    'unknown identity and cooldown do not cause unsolicited login attempts',
    () async {
      final store = SecureStore.memory({
        SecureStore.keyUserId: '1',
        SecureStore.keyLastUsername: 'fake',
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'academic_attempt_1',
        DateTime.now().millisecondsSinceEpoch,
      );
      await AcademicSync(store).sync(1);
      expect(await store.read(AcademicClient.credentialKey(1)), isNull);
      await AcademicSync(store).sync(2, force: true);
      expect(prefs.getInt('academic_attempt_2'), isNull);
    },
  );
  test(
    'sync merges in-flight requests, completes, caches, and rejects late publication after account switch',
    () async {
      final store = SecureStore.memory({
        SecureStore.keyUserId: '1',
        SecureStore.keyLastUsername: 'fake',
      });
      var pending = Completer<AcademicSchedule>();
      final client = _PendingClient(store, () => pending.future);
      var publications = 0;
      final sync = AcademicSync(
        store,
        createClient: (_) => client,
        onUpdated: (_) => publications++,
      );
      final first = sync.sync(1);
      final second = sync.sync(1);
      expect(identical(first, second), isTrue);
      for (var i = 0; i < 20 && client.calls == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(client.calls, 1);
      final initial = AcademicSchedule(
        term: '20261',
        monday: DateTime(2026, 9, 7),
        fetchedAt: DateTime.now(),
        rows: [],
      );
      pending.complete(initial);
      await Future.wait([first, second]);
      expect(
        (await AcademicScheduleStore.read(1))!.fetchedAt,
        initial.fetchedAt,
      );
      await sync.sync(1);
      expect(client.calls, 1);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('academic_attempt_1', 0);
      pending = Completer<AcademicSchedule>();
      final late = sync.sync(1, force: true);
      for (var i = 0; i < 20 && client.calls == 1; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(client.calls, 2);
      await store.write(SecureStore.keyUserId, '2');
      pending.complete(
        AcademicSchedule(
          term: '20262',
          monday: DateTime(2027, 2, 15),
          fetchedAt: DateTime.now(),
          rows: [],
        ),
      );
      await late;
      expect((await AcademicScheduleStore.read(1))!.term, '20261');
      expect(await AcademicScheduleStore.read(2), isNull);
      client.dio.close();
    },
  );
  test(
    'failed academic requests preserve the cache and manual sync cannot bypass failure backoff',
    () async {
      final store = SecureStore.memory({
        SecureStore.keyUserId: '1',
        SecureStore.keyLastUsername: 'fake',
      });
      final old = AcademicSchedule(
        term: '20261',
        monday: DateTime(2026, 9, 7),
        fetchedAt: DateTime(2026, 9, 7),
        rows: [],
      );
      await AcademicScheduleStore.write(1, old);
      var attempts = 0;
      final sync = AcademicSync(
        store,
        createClient: (_) {
          attempts++;
          throw StateError('offline');
        },
      );
      await sync.sync(1, force: true);
      expect(attempts, 1);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('academic_attempt_1', 0);
      await sync.sync(1, force: true);
      expect(attempts, 1);
      expect(sync.error, contains('暂缓'));
      expect((await AcademicScheduleStore.read(1))!.fetchedAt, old.fetchedAt);
      sync.dispose();
    },
  );
}
