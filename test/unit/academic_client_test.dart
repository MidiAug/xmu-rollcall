import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';
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
  String? receivedPassword;
  CookieJar? receivedSso;
  @override
  Future<AcademicSchedule> fetch(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    DateTime? at,
  }) {
    calls++;
    receivedPassword = password;
    receivedSso = sso;
    return result();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'assist timetable uses its own credentials and IDS jar, and writes only its cache',
    () async {
      final store = SecureStore.memory({
        SecureStore.keyUserId: '1',
        SecureStore.keyLastUsername: '2099000000001',
        SecureStore.keyOwnerPassword: 'owner-password',
      });
      final assistJar = CookieJar();
      final client = _PendingClient(
        store,
        () async => AcademicSchedule(
          term: '20261',
          monday: DateTime(2026, 9, 14),
          fetchedAt: DateTime.now(),
          rows: [],
        ),
      );
      final sync = AcademicSync(
        store,
        createClient: (_) => client,
        currentSso: () =>
            throw StateError('must not read owner SSO for assist'),
        resolveIdentity: (uid) async => AcademicIdentity(
          username: '2099000000002',
          password: 'assist-password',
          sso: assistJar,
          isCurrent: () async => true,
        ),
      );
      await sync.sync(2);
      expect(client.receivedPassword, 'assist-password');
      expect(client.receivedSso, same(assistJar));
      expect(await AcademicScheduleStore.read(2), isNotNull);
      expect(await AcademicScheduleStore.read(1), isNull);
      sync.dispose();
    },
  );
  test(
    'removing an assist while the request is pending prevents publication',
    () async {
      final store = SecureStore.memory({SecureStore.keyUserId: '1'});
      var present = true;
      final result = Completer<AcademicSchedule>();
      final entered = Completer<void>();
      final client = _PendingClient(store, () {
        entered.complete();
        return result.future;
      });
      final sync = AcademicSync(
        store,
        createClient: (_) => client,
        resolveIdentity: (_) async => AcademicIdentity(
          username: '2099000000002',
          password: 'assist-password',
          isCurrent: () async => present,
        ),
      );
      final request = sync.sync(2);
      await entered.future;
      present = false;
      result.complete(
        AcademicSchedule(
          term: '20261',
          monday: DateTime(2026, 9, 14),
          fetchedAt: DateTime.now(),
          rows: [],
        ),
      );
      await request;
      expect(await AcademicScheduleStore.read(2), isNull);
      sync.dispose();
    },
  );
  test(
    'queued academic requests validate the target identity before sending',
    () async {
      final client = AcademicClient(
        store: SecureStore.memory({SecureStore.keyUserId: '1'}),
        limiter: RateLimiter(minInterval: Duration.zero, maxPerMinute: 100),
      )..identityGuard = () async => false;
      await expectLater(
        client.fetch(2, username: '2099000000002'),
        throwsStateError,
      );
    },
  );
  test(
    'restored account reuses secure remembered password and current IDS jar after upgrade',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'academic_failure_1',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setInt(
        'academic_attempt_1',
        DateTime.now().millisecondsSinceEpoch,
      );
      final store = SecureStore.memory({
        SecureStore.keyUserId: '1',
        SecureStore.keyLastUsername: 'fake',
        SecureStore.keyOwnerPassword: 'fake-remembered',
      });
      final jar = CookieJar();
      final client = _PendingClient(
        store,
        () async => AcademicSchedule(
          term: '20261',
          monday: DateTime(2026, 9, 7),
          fetchedAt: DateTime.now(),
          rows: [],
        ),
      );
      final sync = AcademicSync(
        store,
        createClient: (_) => client,
        currentSso: () => jar,
      );
      await sync.sync(1);
      expect(client.calls, 1);
      expect(client.receivedPassword, 'fake-remembered');
      expect(identical(client.receivedSso, jar), isTrue);
      expect(sync.errorFor(1), isNull);
      expect((await AcademicScheduleStore.read(1))!.term, '20261');
      expect(prefs.getInt('academic_failure_1'), isNull);
      client.dio.close();
      sync.dispose();
    },
  );
  test(
    'interactive login retries an in-flight restore that lacked credentials without 30 minute lockout',
    () async {
      final store = SecureStore.memory({
        SecureStore.keyUserId: '1',
        SecureStore.keyLastUsername: 'fake',
      });
      final pending = Completer<AcademicSchedule>();
      final first = _PendingClient(store, () => pending.future);
      final second = _PendingClient(
        store,
        () async => AcademicSchedule(
          term: '20261',
          monday: DateTime(2026, 9, 7),
          fetchedAt: DateTime.now(),
          rows: [],
        ),
      );
      var created = 0;
      final sync = AcademicSync(
        store,
        createClient: (_) => created++ == 0 ? first : second,
      );
      final restore = sync.sync(1);
      for (var i = 0; i < 20 && first.calls == 0; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final login = sync.sync(
        1,
        username: 'fake',
        password: 'fresh-fake',
        force: true,
      );
      pending.completeError(const AcademicLoginRequired());
      await Future.wait([restore, login]);
      expect(second.receivedPassword, 'fresh-fake');
      expect(sync.needsLogin(1), isFalse);
      expect(await AcademicScheduleStore.read(1), isNotNull);
      first.dio.close();
      second.dio.close();
      sync.dispose();
    },
  );
  test(
    'missing password requests login without pretending a previous academic timetable exists',
    () async {
      final store = SecureStore.memory({
        SecureStore.keyUserId: '1',
        SecureStore.keyLastUsername: 'fake',
      });
      final sync = AcademicSync(
        store,
        createClient: (_) => throw const AcademicLoginRequired(),
      );
      await sync.sync(1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('academic_failure_1'), isNull);
      expect(sync.needsLogin(1), isTrue);
      expect(sync.errorFor(1), contains('重新登录'));
      expect(sync.errorFor(1), isNot(contains('上次课表')));
      expect(sync.errorFor(2), isNull);
      sync.dispose();
    },
  );
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
  for (final expiredSession in [false, true]) {
    test(
      'isolated CAS handles anonymous 404 or expired redirect ($expiredSession), then reads full term',
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
                  final initial = ++appEntries == 1;
                  status = initial ? (expiredSession ? 302 : 404) : 200;
                  if (expiredSession && initial) {
                    headers = {
                      'location': ['/gsapp/sys/wdkbapp/*default/index.do'],
                    };
                  }
                  body = '<html>academic application</html>';
                case '/gsapp/sys/wdkbapp/*default/index.do':
                  status = 302;
                  headers = {
                    'location': [
                      'https://ids.xmu.edu.cn/authserver/login?service=https%3A%2F%2Fjw.xmu.edu.cn%2Flogin',
                    ],
                  };
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
                      {'XH': 'fake-student', 'XYMC': '信息学院'},
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
        expect(result.studentCollege, '信息学院');
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
  }
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
      expect(sync.error, contains('上次课表'));
      expect((await AcademicScheduleStore.read(1))!.fetchedAt, old.fetchedAt);
      sync.dispose();
    },
  );
  test(
    'unknown new semester week one can fetch with a user-selected Monday',
    () async {
      final store = SecureStore.memory({SecureStore.keyUserId: '7'});
      await SemesterPreferences.save(7, '20271', DateTime(2027, 9, 6));
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, handler) {
            final Object body;
            switch (r.uri.path) {
              case '/appShow':
                body = '<html>ready</html>';
              case '/gsapp/sys/wdkbapp/wdkcb/initXsxx.do':
                body = {
                  'success': true,
                  'data': [
                    {'XH': 'fake'},
                  ],
                };
              case '/gsapp/sys/wdkbapp/modules/xskcb/kfdxnxqcx.do':
                body = {
                  'datas': {
                    'kfdxnxqcx': {
                      'rows': [
                        {'XNXQDM': '20271'},
                      ],
                    },
                  },
                };
              case '/gsapp/sys/wdkbapp/wdkcb/getZcxx.do':
                body = {'success': true, 'currentZc': '1'};
              case '/gsapp/sys/wdkbapp/wdkcb/queryXsskjc.do':
                body = {
                  'data': [
                    {'DM': '3', 'KSSJ': 1010, 'JSSJ': 1055},
                  ],
                };
              case '/gsapp/sys/wdkbapp/wdkcb/queryXspkjg.do':
                body = {
                  'success': true,
                  'pkjgList': [
                    {
                      'KCDM': 'fake',
                      'KCMC': '测试课程',
                      'BJDM': 'A',
                      'XQ': 1,
                      'ZCBH': '1000',
                      'KSJCDM': 3,
                      'JSJCDM': 3,
                    },
                  ],
                  'ttbList': [],
                };
              default:
                throw StateError('unexpected endpoint');
            }
            handler.resolve(
              Response(
                requestOptions: r,
                statusCode: 200,
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
        username: 'fake',
        at: DateTime(2027, 9, 8),
      );
      expect(result.monday, DateTime(2027, 9, 6));
      expect(result.anchorFromUser, isTrue);
      expect(result.allTables[1]!.single.dates, {'2027-09-06'});
      await AcademicScheduleStore.write(7, result);
      expect(
        (await AcademicScheduleStore.read(7))!.monday,
        DateTime(2027, 9, 6),
      );
    },
  );
  test(
    'correcting a missing calendar permits retry, while actual network failure still backs off',
    () async {
      final store = SecureStore.memory({
        SecureStore.keyUserId: '1',
        SecureStore.keyLastUsername: 'fake',
      });
      var attempts = 0;
      final sync = AcademicSync(
        store,
        createClient: (_) {
          attempts++;
          if (attempts == 1) throw const AcademicCalendarUnavailable('20271');
          return _PendingClient(
            store,
            () async => AcademicSchedule(
              term: '20271',
              monday: DateTime(2027, 9, 6),
              anchorFromUser: true,
              fetchedAt: DateTime.now(),
              rows: [],
            ),
          );
        },
      );
      await sync.sync(1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('academic_failure_1'), isNull);
      expect(prefs.getString('academic_calendar_missing_1'), '20271');
      await SemesterPreferences.save(1, '20271', DateTime(2027, 9, 6));
      await sync.sync(1);
      expect(attempts, 2);
      expect(prefs.getString('academic_calendar_missing_1'), isNull);
      expect(
        (await AcademicScheduleStore.read(1))!.monday,
        DateTime(2027, 9, 6),
      );
      sync.dispose();
    },
  );
}
