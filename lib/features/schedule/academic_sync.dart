import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/log_redactor.dart';
import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import 'academic_timetable_reader.dart';
import 'academic_schedule.dart';
import 'academic_calendar.dart';
import 'semester_preferences.dart';

/// Only weeks 1–2 refresh weekly; later weeks reuse this term's saved schedule.
bool academicScheduleCacheIsFresh(AcademicSchedule schedule, DateTime now) {
  final term = currentSemester(now);
  final newerTerm = term.compareTo(schedule.term) > 0;
  // Fetch once after a new term begins, including a schedule published before it.
  // The fetch timestamp also prevents rechecking every visit if JW still returns the old term.
  if (term.compareTo(schedule.term) >= 0 &&
      currentSemester(schedule.fetchedAt).compareTo(term) < 0) {
    return false;
  }
  final start = newerTerm
      ? academicMondays[term] ?? schedule.monday
      : schedule.monday;
  final day = semesterDate(now).difference(semesterDate(start)).inDays;
  if (day < 0 || day >= 14) return true;
  return now.difference(schedule.fetchedAt) < const Duration(days: 7);
}

class AcademicSync {
  AcademicSync(
    this.store, {
    AcademicTimetableReader Function(SecureStore)? createReader,
    this.onUpdated,
    this.currentSso,
    this.resolveIdentity,
    this.currentUserId,
    this.periodic = false,
  }) : createReader =
           createReader ??
           ((store) => AcademicTimetableReader(AcademicSession(store: store)));
  final SecureStore store;
  final AcademicTimetableReader Function(SecureStore) createReader;
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
    // Check local cooldowns before opening credentials or restoring sessions.
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
        academicScheduleCacheIsFresh(cached, now)) {
      return;
    }
    AcademicIdentity? access;
    try {
      access = resolveIdentity == null ? null : await resolveIdentity!(uid);
    } catch (_) {
      _setError(uid, '该账号的认证信息不可用，请重新导入', login: true);
      return;
    }
    if (access == null && '$uid' == owner) {
      access = await resolveOwnerAcademicIdentity(
        store,
        uid,
        sso: currentSso?.call(),
      );
    }
    if (access == null) {
      _setError(uid, '请补充该协助账号的认证信息以连接教务课表', login: true);
      return;
    }
    final identity = access;
    Future<bool> current() async => !_disposed && await identity.isCurrent();
    if (!await current()) return;
    username ??= identity.username;
    password ??= identity.password;
    sso ??= identity.sso;
    if ((username == null || username.isEmpty) &&
        sso == null &&
        await store.read(AcademicSession.credentialKey(uid)) == null) {
      _setError(uid, '请重新登录账号以连接教务课表', login: true);
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
      final reader = createReader(store);
      reader.session.identityGuard = current;
      final next = await reader.fetch(
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
