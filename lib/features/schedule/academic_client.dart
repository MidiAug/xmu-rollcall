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
    return limiter.schedule(
      () => dio.requestUri<dynamic>(
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
      ),
      priority: RequestPriority.background,
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
          throw const FormatException('教务需要重新登录，请重新登录账号以连接课表');
        }
        submitted = true;
        uri = await IdsAuth(
          hop,
        ).submit(url: uri, html: html, username: username, password: password);
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
      final cached = await AcademicScheduleStore.read(uid);
      final monday = academicMonday(
        term,
        currentWeek,
        now,
        cached: cached?.term == term ? cached!.monday : null,
      );
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
      );
      if (await store.read(SecureStore.keyUserId) != '$uid') {
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
  if (known.isNotEmpty && now.isBefore(DateTime(2027, 9, 1))) {
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

class AcademicSync {
  AcademicSync(
    this.store, {
    AcademicClient Function(SecureStore)? createClient,
    this.onUpdated,
    this.periodic = false,
  }) : createClient = createClient ?? ((store) => AcademicClient(store: store));
  final SecureStore store;
  final AcademicClient Function(SecureStore) createClient;
  final void Function(int uid)? onUpdated;
  final bool periodic;
  Timer? _timer;
  bool _disposed = false;
  void startPeriodic() {
    _timer ??= Timer.periodic(const Duration(hours: 12), (_) {
      unawaited(
        () async {
          final uid = int.tryParse(
            await store.read(SecureStore.keyUserId) ?? '',
          );
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
  Future<void> sync(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    bool force = false,
  }) {
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
    if (_disposed || await store.read(SecureStore.keyUserId) != '$uid') return;
    username ??= await store.read(SecureStore.keyLastUsername);
    if (username == null || username.isEmpty) return;
    if (periodic) startPeriodic();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final cached = await AcademicScheduleStore.read(uid);
    final last = prefs.getInt('academic_attempt_$uid');
    final failure = prefs.getInt('academic_failure_$uid');
    if (failure != null &&
        now.millisecondsSinceEpoch - failure <
            const Duration(minutes: 30).inMilliseconds) {
      error = '教务同步暂缓，请30分钟后再试；保留上次课表';
      return;
    }
    // Stable term weekly, semester boundaries daily, failures 30 minutes.
    final nearStart = {2, 3, 8, 9}.contains(now.month);
    if (last != null &&
        now.millisecondsSinceEpoch - last <
            (force ? const Duration(seconds: 15) : const Duration(minutes: 30))
                .inMilliseconds) {
      return;
    }
    if (!force &&
        cached != null &&
        now.difference(cached.fetchedAt) < Duration(days: nearStart ? 1 : 7)) {
      return;
    }
    await prefs.setInt('academic_attempt_$uid', now.millisecondsSinceEpoch);
    try {
      final next = await createClient(
        store,
      ).fetch(uid, sso: sso, username: username, password: password);
      // A late request must never publish after sign-out or account switch.
      if (_disposed || await store.read(SecureStore.keyUserId) != '$uid') {
        return;
      }
      await AcademicScheduleStore.write(uid, next);
      await prefs.remove('academic_failure_$uid');
      error = null;
      onUpdated?.call(uid);
    } catch (e) {
      await prefs.setInt(
        'academic_failure_$uid',
        DateTime.now().millisecondsSinceEpoch,
      );
      error = e is FormatException && e.source == null
          ? '教务课表未更新：${e.message}'
          : '教务暂时无法连接，保留上次课表，请稍后同步';
    }
  }
}
