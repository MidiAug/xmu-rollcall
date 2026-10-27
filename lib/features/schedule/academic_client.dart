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
              headers: {'User-Agent': TronEndpoints.userAgent},
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
        continue;
      }
      if (response.statusCode != 200 || uri.host == ids.host) {
        throw const FormatException('教务会话未建立');
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
    if (response.statusCode != 200) throw const FormatException('教务会话失效或暂不可用');
    final decoded = jsonDecode('${response.data}');
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('教务数据格式异常');
    }
    return decoded;
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
        monday = academicMonday(
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
        await SemesterPreferences.read(uid, missingTerm) != null;
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
