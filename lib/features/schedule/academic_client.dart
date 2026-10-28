import 'package:crypto/crypto.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/log_redactor.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'dart:async';
import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';
import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/session/cookie_codec.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/auth/ids_auth.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';

class AcademicApplicationDenied extends FormatException {
  const AcademicApplicationDenied() : super('当前账号无该成绩应用权限');
}

class AcademicGradeResult {
  const AcademicGradeResult({
    required this.rows,
    required this.replacedTerms,
    this.education = 'undergraduate',
    this.complete = false,
  });
  final List<Map<String, dynamic>> rows;
  final Set<String> replacedTerms;
  final String education;
  final bool complete;
}

class AcademicSessionRequired implements Exception {
  const AcademicSessionRequired();
}

class AcademicLoginRequired extends FormatException {
  const AcademicLoginRequired([super.message = '请重新登录账号以连接教务课表']);
}

/// Independent, per-identity JW/IDS jar. No TronClass access token is forwarded.
class AcademicClient {
  AcademicClient({required this.store, Dio? dio, RateLimiter? limiter})
    : dio = dio ?? Dio(),
      limiter = limiter ?? RateLimiter() {
    this.dio.options.connectTimeout = const Duration(seconds: 20);
    this.dio.options.receiveTimeout = const Duration(seconds: 30);
  }
  final SecureStore store;
  final Dio dio;
  final RateLimiter limiter;
  final CookieJar jar = CookieJar();
  int? _boundUid;
  Uri? _gradeApplicationPage;
  Future<bool> Function()? identityGuard;
  Future<bool> _identityCurrent(int uid) async => identityGuard != null
      ? identityGuard!()
      : await store.read(SecureStore.keyUserId) == '$uid';
  static final jw = Uri.parse('https://jw.xmu.edu.cn');
  static final ids = Uri.parse('https://ids.xmu.edu.cn');
  static String credentialKey(int uid) => 'academic_session_v1_$uid';

  Future<Response<dynamic>> hop(
    String method,
    Uri uri, {
    Object? data,
    String? contentType,
  }) {
    if (uri.scheme != 'https' || !{jw.host, ids.host}.contains(uri.host)) {
      throw const FormatException('教务登录跳转地址异常');
    }
    final watch = Stopwatch()..start();
    return limiter
        .schedule(() async {
          if (_boundUid != null && !await _identityCurrent(_boundUid!)) {
            throw StateError('账号已切换');
          }
          return dio.requestUri<dynamic>(
            uri,
            data: data,
            options: Options(
              method: method,
              followRedirects: false,
              maxRedirects: 0,
              responseType: ResponseType.plain,
              contentType: contentType,
              validateStatus: (s) => s != null && s < 500,
              headers: {
                'User-Agent': TronEndpoints.userAgent,
                if (uri.host == jw.host &&
                    (uri.path.startsWith('/jwapp/sys/cjcx/modules/') ||
                        uri.path.startsWith('/gsapp/sys/wdcjapp/modules/') ||
                        uri.path ==
                            '/jwapp/sys/jwpubapp/pub/setJwCommonAppRole.do')) ...{
                  'Referer':
                      (_gradeApplicationPage ??
                              jw.resolve('/jwapp/sys/cjcx/*default/index.do'))
                          .toString(),
                  'Origin': jw.origin,
                  'X-Requested-With': 'XMLHttpRequest',
                  'Accept': 'application/json, text/javascript, */*; q=0.01',
                },
              },
            ),
          );
        }, priority: RequestPriority.background)
        .then(
          (response) {
            AppLog.event(
              'academic.http.result',
              fields: {
                'method': method,
                'host': uri.host,
                'path': uri.path,
                'status': response.statusCode,
                'elapsedMs': watch.elapsedMilliseconds,
              },
            );
            return response;
          },
          onError: (Object error, StackTrace stack) {
            AppLog.event(
              'academic.http.error',
              level: 'W',
              fields: {
                ...LogRedactor.exceptionFields(error: error),
                'host': uri.host,
                'path': uri.path,
                'elapsedMs': watch.elapsedMilliseconds,
              },
            );
            Error.throwWithStackTrace(error, stack);
          },
        );
  }

  Future<void> open(Uri uri, {String? username, String? password}) async {
    var submitted = false;
    for (var i = 0; i < 16; i++) {
      final response = await hop('GET', uri);
      // Anonymous appShow currently returns 404. Only this entry permits CAS bootstrap.
      if (response.statusCode == 404 &&
          uri.host == jw.host &&
          uri.path == '/appShow') {
        throw const AcademicSessionRequired();
      }
      if (response.statusCode == 429 || response.statusCode == 403) {
        throw const FormatException('教务暂时拒绝访问，请稍后重试');
      }
      final html = '${response.data ?? ''}';
      if (html.contains('pwdEncryptSalt')) {
        if (submitted || username == null || password == null) {
          throw const AcademicLoginRequired();
        }
        submitted = true;
        try {
          uri = await IdsAuth(hop).submit(
            url: uri,
            html: html,
            username: username,
            password: password,
          );
        } on FormatException catch (error) {
          if (error.source == null &&
              const {
                '需要验证码，请在统一认证中完成登录',
                '统一认证未通过，请检查账号密码',
              }.contains(error.message)) {
            throw AcademicLoginRequired(error.message);
          }
          rethrow;
        }
        continue;
      }
      final location = response.headers.value('location');
      if (location != null &&
          location.isNotEmpty &&
          {301, 302, 303, 307, 308}.contains(response.statusCode)) {
        uri = uri.resolve(location);
        if (uri.host == jw.host && uri.path == '/resources/html/403.html') {
          // A denied application is not an expired CAS session; never fetch its HTTP error page.
          throw const AcademicApplicationDenied();
        }
        continue;
      }
      if (response.statusCode != 200 || uri.host == ids.host) {
        throw const FormatException('教务会话未建立');
      }
      if (uri.host == jw.host &&
          (uri.path == '/jwapp/sys/cjcx/*default/index.do' ||
              uri.path == '/gsapp/sys/wdcjapp/*default/index.do')) {
        // Keep signed application parameters in memory only, never in logs/cache.
        _gradeApplicationPage = uri;
      }
      return;
    }
    throw const FormatException('教务登录跳转过多');
  }

  Future<Map<String, dynamic>> json(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await hop(
      data == null ? 'GET' : 'POST',
      jw.resolve(path),
      data: data,
      contentType: data == null ? null : Headers.formUrlEncodedContentType,
    );
    if ({301, 302, 303, 307, 308, 401}.contains(response.statusCode)) {
      throw const AcademicLoginRequired();
    }
    if (response.statusCode == 403) {
      throw const FormatException('教务拒绝访问（403），请稍后重试');
    }
    if (response.statusCode == 429) {
      throw const FormatException('教务请求过于频繁，请稍后重试');
    }
    if (response.statusCode != 200) throw const FormatException('教务会话失效或暂不可用');
    final decoded = jsonDecode('${response.data}');
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('教务数据格式异常');
    }
    return decoded;
  }

  Future<void> _connect(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
  }) async {
    final raw = await store.read(credentialKey(uid));
    if (raw != null) {
      final saved = jsonDecode(raw) as Map;
      for (final origin in [jw, ids]) {
        if (saved[origin.host] is String) {
          await jar.saveFromResponse(
            origin,
            decodeCookies(saved[origin.host] as String),
          );
        }
      }
    }
    if (sso != null) {
      await jar.saveFromResponse(
        ids,
        await sso.loadForRequest(ids.resolve('/authserver/login')),
      );
    }
    final app = jw
        .resolve('/appShow')
        .replace(queryParameters: {'appId': '4979568947762216'});
    try {
      await open(app, username: username, password: password);
    } on AcademicSessionRequired {
      await open(
        ids
            .resolve('/authserver/login')
            .replace(
              queryParameters: {
                'type': 'userNameLogin',
                'service':
                    'https://jw.xmu.edu.cn/login?service=https://jw.xmu.edu.cn/new/index.html',
              },
            ),
        username: username,
        password: password,
      );
      await open(app);
    }
  }

  /// Grade query reuses the identity's own JW/IDS jar, never capture-file cookies.
  Future<AcademicGradeResult> fetchGrades(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    bool recent = false,
  }) async {
    _boundUid = uid;
    dio.interceptors.add(CookieManager(jar));
    try {
      await _connect(uid, sso: sso, username: username, password: password);
      final identity = await json('/gsapp/sys/wdkbapp/wdkcb/initXsxx.do');
      final person = identity['data'] is List
          ? (identity['data'] as List).singleOrNull
          : identity['data'];
      final student = person is Map ? academicText(person['XH']) : '';
      if (identity['success'] != true ||
          student.isEmpty ||
          (username != null && student != username)) {
        throw const FormatException('教务身份与所选账号不一致');
      }
      try {
        await open(
          jw
              .resolve('/appShow')
              .replace(queryParameters: {'appId': '4768574631264620'}),
        );
      } on AcademicApplicationDenied {
        await open(
          jw
              .resolve('/appShow')
              .replace(queryParameters: {'appId': '5094115980385668'}),
        );
        return await _graduateGrades(student);
      }
      // The official grade page initializes the student's JW application role
      // before issuing queries; a valid CAS login alone does not do this.
      final role = await json(
        '/jwapp/sys/jwpubapp/pub/setJwCommonAppRole.do',
        data: {},
      );
      if (role['success'] != true && '${role['success']}' != '1') {
        throw const FormatException('教务成绩应用初始化失败，请稍后重试');
      }
      const base = '/jwapp/sys/cjcx/modules/cjcx/';
      final terms = <String>{};
      if (recent) {
        final result = await json('${base}cxdqxnxqhsygxnxq.do', data: {});
        final rows =
            ((result['datas'] as Map?)?['cxdqxnxqhsygxnxq'] as Map?)?['rows'];
        if (rows is! List || rows.isEmpty) {
          throw const FormatException('近两学期信息暂不可用');
        }
        for (final row in rows.whereType<Map>()) {
          final term = academicText(row['XNXQDM']);
          if (!RegExp(r'^\d{4}-\d{4}-[1239]$').hasMatch(term)) {
            throw const FormatException('成绩学期格式异常');
          }
          terms.add(term);
        }
        if (terms.isEmpty) throw const FormatException('近两学期信息暂不可用');
      }
      final output = <Map<String, dynamic>>[];
      final ids = <String>{};
      for (final term in recent ? terms.cast<String?>() : <String?>[null]) {
        var loaded = 0;
        for (var page = 1; page <= 100; page++) {
          final result = await json(
            '${base}xscjcx.do',
            data: {
              'querySetting': jsonEncode([
                {
                  'name': 'SFYX',
                  'linkOpt': 'AND',
                  'builder': 'm_value_equal',
                  'value': '1',
                },
                {
                  'name': 'SHOWMAXCJ',
                  'linkOpt': 'AND',
                  'builder': 'm_value_equal',
                  'value': '0',
                },
                if (term != null)
                  {
                    'name': 'XNXQDM',
                    'linkOpt': 'AND',
                    'builder': 'm_value_equal',
                    'value': term,
                  },
              ]),
              '*order': '-XNXQDM,-KCH,-KXH',
              'pageSize': 999,
              'pageNumber': page,
            },
          );
          final node = (result['datas'] as Map?)?['xscjcx'];
          if (node is! Map || node['rows'] is! List) {
            throw const FormatException('成绩数据格式异常');
          }
          final meta = node['extParams'];
          if (meta is Map && meta['code'] != null && '${meta['code']}' != '1') {
            throw const FormatException('成绩查询未成功，请稍后重试');
          }
          final rows = (node['rows'] as List).whereType<Map>().toList();
          var added = 0;
          for (final row in rows) {
            if (row['XH'] != null && academicText(row['XH']) != student) {
              throw const FormatException('成绩数据身份不一致');
            }
            final id = academicText(row['WID']);
            if (id.isEmpty) throw const FormatException('成绩记录缺少标识');
            if (!ids.add(id)) continue;
            added++;
            // Minimized local data: no student number, identity or session fields.
            output.add({
              for (final key in [
                'WID',
                'KCH',
                'KCM',
                'XSKCM',
                'XNXQDM',
                'XNXQDM_DISPLAY',
                'XF',
                'JDF',
                'XFJD',
                'ZCJ',
                'DJCJMC',
                'SFYX',
                'XSZCJMC',
                'DJCJLXDM',
                'DJCJLXDM_DISPLAY',
                'KCXZDM_DISPLAY',
                'KCLBDM_DISPLAY',
                'XDFSDM_DISPLAY',
                'SFZX_DISPLAY',
              ])
                key: row[key],
            });
          }
          loaded += rows.length;
          final total = academicInt(node['totalSize']);
          if (loaded >= total) break;
          if (rows.isEmpty || added == 0 || page == 100) {
            throw const FormatException('成绩分页不完整，请稍后重试');
          }
        }
      }
      if (!await _identityCurrent(uid)) throw StateError('账号已切换');
      return AcademicGradeResult(rows: output, replacedTerms: terms);
    } finally {
      dio.close();
    }
  }

  /// Graduate application uses a different model and publishes no rows before grades exist.
  Future<AcademicGradeResult> _graduateGrades(String student) async {
    final output = <Map<String, dynamic>>[];
    final pages = <String>{};
    final occurrences = <String, int>{};
    var loaded = 0;
    for (var page = 1; page <= 100; page++) {
      final result = await json(
        '/gsapp/sys/wdcjapp/modules/wdcj/xscjcx_by.do',
        data: {'pageSize': 100, 'pageNumber': page},
      );
      final node = (result['datas'] as Map?)?['xscjcx_by'];
      if (node is! Map ||
          node['rows'] is! List ||
          result['success'] == false ||
          (result['code'] != null && '${result['code']}' != '0')) {
        throw const FormatException('研究生成绩数据格式异常');
      }
      final rows = (node['rows'] as List).whereType<Map>().toList();
      if (rows.length != (node['rows'] as List).length) {
        throw const FormatException('研究生成绩记录格式异常');
      }
      if (!pages.add(
            sha256.convert(utf8.encode(jsonEncode(rows))).toString(),
          ) &&
          rows.isNotEmpty) {
        throw const FormatException('研究生成绩分页不完整');
      }
      for (final row in rows) {
        if (row['XH'] != null && academicText(row['XH']) != student) {
          throw const FormatException('成绩数据身份不一致');
        }
        final rawTerm = academicText(row['XNXQDM']);
        final short = RegExp(r'^(\d{4})([1239])$').firstMatch(rawTerm);
        final term = short == null
            ? rawTerm
            : '${short[1]}-${int.parse(short[1]!) + 1}-${short[2]}';
        final minimal = <String, dynamic>{
          'KCH': row['KCDM'],
          'KCM': row['KCMC'],
          'XNXQDM': term,
          'XF': row['XF'],
          'JDF': row['JDZ'],
          'ZCJ': row['CJ'],
          'XSZCJMC': row['CJXSZ'] ?? row['CJ'],
          'SFYX': row['SFYX'] ?? '1',
          'DJCJLXDM_DISPLAY': row['CJFZDM_DISPLAY'],
          'KCLBDM_DISPLAY': row['KCLBDM_DISPLAY'],
          'GRADE_SYSTEM': 'graduate',
        };
        final base = sha256
            .convert(
              utf8.encode(
                jsonEncode([
                  minimal,
                  row['KSXZDM'],
                  row['BJDM'],
                  row['ZTDM'],
                  row['TSZTDM'],
                ]),
              ),
            )
            .toString();
        final occurrence = occurrences.update(
          base,
          (n) => n + 1,
          ifAbsent: () => 0,
        );
        minimal['WID'] = academicText(row['WID']).isNotEmpty
            ? 'gs:${row['WID']}'
            : 'gs:$base:$occurrence';
        output.add(minimal);
      }
      loaded += rows.length;
      final total = academicInt(node['totalSize']);
      if (loaded >= total) {
        if (_boundUid != null && !await _identityCurrent(_boundUid!)) {
          throw StateError('账号已切换');
        }
        return AcademicGradeResult(
          rows: output,
          replacedTerms: const {},
          education: 'graduate',
          complete: true,
        );
      }
      if (rows.isEmpty || page == 100) {
        throw const FormatException('研究生成绩分页不完整');
      }
    }
    throw const FormatException('研究生成绩分页不完整');
  }

  Future<AcademicSchedule> fetch(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    DateTime? at,
  }) async {
    _boundUid = uid;
    final now = at ?? DateTime.now();
    dio.interceptors.add(CookieManager(jar));
    try {
      await _connect(uid, sso: sso, username: username, password: password);
      const base = '/gsapp/sys/wdkbapp/';
      final identity = await json('${base}wdkcb/initXsxx.do');
      final rawPerson = identity['data'];
      final person = rawPerson is List && rawPerson.length == 1
          ? rawPerson.single
          : rawPerson;
      final student = person is Map ? academicText(person['XH']) : '';
      if (identity['success'] != true ||
          student.isEmpty ||
          (username != null && student != username)) {
        throw const FormatException('教务身份与登录账号不一致');
      }
      final terms = await json('${base}modules/xskcb/kfdxnxqcx.do', data: {});
      final available =
          ((terms['datas'] as Map?)?['kfdxnxqcx'] as Map?)?['rows'] as List?;
      final term = selectAcademicTerm(available ?? [], now);
      final week = await json(
        '${base}wdkcb/getZcxx.do',
        data: {'XNXQDM': term},
      );
      final currentWeek = academicInt(week['currentZc']);
      if (week['success'] != true || currentWeek < 1 || currentWeek > 30) {
        throw const FormatException('教务当前周次不可用');
      }
      final cached = await AcademicScheduleStore.read(uid, useUserStart: false);
      late final DateTime monday;
      var anchorFromUser = false;
      try {
        monday =
            await platformSemesterMonday(uid, term) ??
            academicMonday(
              term,
              currentWeek,
              now,
              cached: cached?.term == term && cached?.anchorFromUser != true
                  ? cached!.monday
                  : null,
            );
      } on AcademicCalendarUnavailable {
        final manual = await SemesterPreferences.read(uid, term);
        if (manual == null) rethrow;
        monday = manual;
        anchorFromUser = true;
      }
      final periods = await json(
        '${base}wdkcb/queryXsskjc.do',
        data: {'XNXQDM': term, 'XH': student},
      );
      final clock = <int, ({int start, int end})>{
        for (final p in periods['data'] as List? ?? const [])
          academicInt((p as Map)['DM']): (
            start: academicMinute(p['KSSJ']),
            end: academicMinute(p['JSSJ']),
          ),
      };
      final payload = await json(
        '${base}wdkcb/queryXspkjg.do',
        data: {'XNXQDM': term, 'XH': student},
      ); // No ZC: entire semester.
      final schedule = AcademicSchedule.parse(
        term: term,
        monday: monday,
        at: now,
        payload: payload,
        studentCollege: academicStudentCollege(person),
        clock: clock,
        anchorFromUser: anchorFromUser,
      );
      if (!await _identityCurrent(uid)) {
        throw StateError('账号已切换');
      }
      await store.write(
        credentialKey(uid),
        jsonEncode({
          for (final origin in [jw, ids])
            origin.host: encodeCookies(
              await jar.loadForRequest(
                origin.resolve(
                  origin == ids ? '/authserver/login' : '/gsapp/sys/wdkbapp/',
                ),
              ),
            ),
        }),
      );
      return schedule;
    } finally {
      dio.close();
    }
  }
}

/// Future published terms must not displace this season's term.
String selectAcademicTerm(List rows, DateTime now) {
  final year = now.month >= 8 ? now.year : now.year - 1;
  final season = now.month >= 8 || now.month == 1
      ? 1
      : now.month >= 7
      ? 3
      : 2;
  var ceiling = '$year$season';
  // Resolve early-published spring/summer schedules against actual teaching starts.
  final known =
      academicMondays.entries.where((e) => !e.value.isAfter(now)).toList()
        ..sort((a, b) => a.value.compareTo(b.value));
  if (known.isNotEmpty && academicMondays.containsKey('$year$season')) {
    ceiling = known.last.key;
  }
  final codes =
      rows
          .map((r) => academicText((r as Map)['XNXQDM']))
          .where(
            (c) =>
                RegExp(r'^\d{4}[123]$').hasMatch(c) &&
                c.compareTo(ceiling) <= 0,
          )
          .toList()
        ..sort();
  if (codes.isEmpty || codes.last != ceiling) {
    throw const FormatException('本学期课表尚未开放，请稍后刷新');
  }
  return codes.last;
}

class AcademicIdentity {
  const AcademicIdentity({
    this.username,
    this.password,
    this.sso,
    required this.isCurrent,
  });
  final String? username, password;
  final CookieJar? sso;
  final Future<bool> Function() isCurrent;
}

class AcademicSync {
  AcademicSync(
    this.store, {
    AcademicClient Function(SecureStore)? createClient,
    this.onUpdated,
    this.currentSso,
    this.resolveIdentity,
    this.currentUserId,
    this.periodic = false,
  }) : createClient = createClient ?? ((store) => AcademicClient(store: store));
  final SecureStore store;
  final AcademicClient Function(SecureStore) createClient;
  final void Function(int uid)? onUpdated;
  final CookieJar? Function()? currentSso;
  final Future<AcademicIdentity?> Function(int uid)? resolveIdentity;
  final int? Function()? currentUserId;
  final bool periodic;
  Timer? _timer;
  bool _disposed = false;
  void startPeriodic() {
    _timer ??= Timer.periodic(const Duration(hours: 12), (_) {
      unawaited(
        () async {
          final uid =
              currentUserId?.call() ??
              int.tryParse(await store.read(SecureStore.keyUserId) ?? '');
          if (!_disposed && uid != null) await sync(uid);
        }().catchError((Object _) {}),
      );
    });
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }

  final Map<int, Future<void>> _flights = {};
  String? error;
  final Map<int, String> _errors = {};
  final Set<int> _loginRequired = {};
  String? errorFor(int uid) => _errors[uid];
  bool needsLogin(int uid) => _loginRequired.contains(uid);
  void _setError(int uid, String? message, {bool login = false}) {
    error = message;
    if (message == null) {
      _errors.remove(uid);
    } else {
      _errors[uid] = message;
    }
    if (login) {
      _loginRequired.add(uid);
    } else {
      _loginRequired.remove(uid);
    }
  }

  Future<void> sync(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    bool force = false,
  }) {
    final existing = _flights[uid];
    if (existing != null && (password != null || sso != null)) {
      return existing.then((_) async {
        if (needsLogin(uid)) {
          await sync(
            uid,
            sso: sso,
            username: username,
            password: password,
            force: true,
          );
        }
      });
    }
    return _flights[uid] ??=
        _sync(
          uid,
          sso: sso,
          username: username,
          password: password,
          force: force,
        ).whenComplete(() {
          _flights.remove(uid);
        });
  }

  Future<void> _sync(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    bool force = false,
  }) async {
    final owner = await store.read(SecureStore.keyUserId);
    if (_disposed || owner == null) return;
    final freshLogin = password != null || sso != null;
    AcademicIdentity? access;
    try {
      access = resolveIdentity == null ? null : await resolveIdentity!(uid);
    } catch (_) {
      _setError(uid, '该账号的认证信息不可用，请重新导入', login: true);
      return;
    }
    if ('$uid' != owner && access == null) {
      _setError(uid, '请补充该协助账号的认证信息以连接教务课表', login: true);
      return;
    }
    Future<bool> current() async =>
        !_disposed &&
        await store.read(SecureStore.keyUserId) == owner &&
        (access == null || await access.isCurrent());
    if (!await current()) return;
    if ('$uid' == owner) {
      username ??= await store.read(SecureStore.keyLastUsername);
      password ??= await store.read(SecureStore.keyOwnerPassword);
      sso ??= currentSso?.call();
    } else {
      username ??= access!.username;
      password ??= access!.password;
      sso ??= access!.sso;
    }
    if ((username == null || username.isEmpty) &&
        sso == null &&
        await store.read(AcademicClient.credentialKey(uid)) == null) {
      _setError(uid, '请重新登录账号以连接教务课表', login: true);
      return;
    }
    if (periodic) startPeriodic();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final cached = await AcademicScheduleStore.read(uid);
    final missingTerm = prefs.getString('academic_calendar_missing_$uid');
    final calendarCorrected =
        missingTerm != null &&
        (await SemesterPreferences.read(uid, missingTerm) != null ||
            await platformSemesterMonday(uid, missingTerm) != null);
    final last = calendarCorrected
        ? null
        : prefs.getInt('academic_attempt_$uid');
    final failure = prefs.getInt('academic_failure_$uid');
    final failureKind = prefs.getString('academic_failure_kind_$uid');
    if (failureKind == 'login_required') {
      _setError(uid, '请重新登录账号以连接教务课表', login: true);
    }
    // Legacy failures had no diagnostics; allow one classified attempt after upgrade.
    final legacyFailure = failure != null && failureKind == null;
    if (failure != null &&
        failureKind == 'request' &&
        now.millisecondsSinceEpoch - failure <
            const Duration(minutes: 30).inMilliseconds) {
      _setError(uid, cached == null ? '教务暂时无法连接，请稍后再试' : '教务暂时无法连接，显示上次课表');
      AppLog.event(
        'academic.sync.skipped',
        fields: {'reason': 'failure_backoff'},
      );
      return;
    }
    // Stable term weekly, semester boundaries daily, failures 30 minutes.
    final nearStart = {2, 3, 8, 9}.contains(now.month);
    if (!freshLogin &&
        !legacyFailure &&
        last != null &&
        now.millisecondsSinceEpoch - last <
            (force ? const Duration(seconds: 15) : const Duration(minutes: 30))
                .inMilliseconds) {
      return;
    }
    if (!force &&
        !calendarCorrected &&
        cached != null &&
        now.difference(cached.fetchedAt) < Duration(days: nearStart ? 1 : 7)) {
      return;
    }
    await prefs.setInt('academic_attempt_$uid', now.millisecondsSinceEpoch);
    AppLog.event(
      'academic.sync.start',
      fields: {
        'session': '$uid' == owner ? 'owner' : 'assist',
        'hasCachedSchedule': cached != null,
        'hasSso': sso != null,
        'hasSavedPassword': password != null,
        'freshLogin': freshLogin,
      },
    );
    try {
      final client = createClient(store)..identityGuard = current;
      final next = await client.fetch(
        uid,
        sso: sso,
        username: username,
        password: password,
      );
      // A late request must never publish after sign-out or account switch.
      if (!await current()) {
        return;
      }
      await AcademicScheduleStore.write(uid, next);
      await prefs.remove('academic_failure_$uid');
      await prefs.remove('academic_failure_kind_$uid');
      await prefs.remove('academic_calendar_missing_$uid');
      _setError(uid, null);
      AppLog.event(
        'academic.sync.success',
        fields: {
          'session': '$uid' == owner ? 'owner' : 'assist',
          'term': next.term,
          'courses': next.groups.length,
          'meetings': next.rows.length,
        },
      );
      onUpdated?.call(uid);
    } catch (e) {
      if (!await current()) {
        return;
      }
      final login = e is AcademicLoginRequired;
      AppLog.event(
        'academic.sync.failure',
        level: 'W',
        fields: {
          'session': '$uid' == owner ? 'owner' : 'assist',
          ...LogRedactor.exceptionFields(error: e),
          'reason': login
              ? 'login_required'
              : e is AcademicCalendarUnavailable
              ? 'calendar_unavailable'
              : 'request',
          'hasCachedSchedule': cached != null,
        },
      );
      if (login) {
        await prefs.remove('academic_failure_$uid');
        await prefs.setString('academic_failure_kind_$uid', 'login_required');
      } else if (e is AcademicCalendarUnavailable) {
        await prefs.setString('academic_calendar_missing_$uid', e.term);
      } else if (!login) {
        await prefs.setString('academic_failure_kind_$uid', 'request');
        await prefs.setInt(
          'academic_failure_$uid',
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      _setError(
        uid,
        login
            ? e.message
            : e is FormatException && e.source == null
            ? '教务课表未更新：${e.message}'
            : cached == null
            ? '暂时无法获取教务课表，请稍后重试'
            : '教务暂时无法连接，显示上次课表',
        login: login,
      );
    }
  }
}
