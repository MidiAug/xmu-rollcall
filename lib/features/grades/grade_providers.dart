import 'grade_release_policy.dart';
import 'package:xmu_rollcall/features/exams/exam_providers.dart';
export 'grade_release_policy.dart' show gradeReleaseWindow;
import 'dart:async';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import 'academic_grade_reader.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'grade_models.dart';

String gradeCacheKey(int owner, int uid) => 'grades_v1_${owner}_$uid';
final gradeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final gradeReaderProvider = Provider<AcademicGradeReader Function()>((ref) {
  final createSession = ref.watch(academicSessionFactoryProvider);
  return () => AcademicGradeReader(createSession(), queryExams: true);
});
final gradeSnapshotProvider =
    AsyncNotifierProvider.autoDispose<GradeNotifier, GradeSnapshot>(
      GradeNotifier.new,
    );

class GradeNotifier extends AutoDisposeAsyncNotifier<GradeSnapshot> {
  int _revision = 0;
  Future<GradeSnapshot>? _flight;
  late int _owner, _uid;
  GradeSnapshot? _cache;
  String? warning;
  @override
  Future<GradeSnapshot> build() async {
    final revision = ++_revision;
    ref.onDispose(() => _revision++);
    final auth = ref.watch(authControllerProvider);
    final scope = ref.watch(selectedRollcallAccountProvider);
    if (!auth.isSignedIn || auth.profile == null) {
      throw const FormatException('请先登录');
    }
    _owner = auth.profile!.id;
    _uid = scope ?? _owner;
    _cache = null;
    _flight = null;
    warning = null;
    final prefs = await SharedPreferences.getInstance();
    if (revision != _revision) throw StateError('账号已切换');
    try {
      final raw = prefs.getString(gradeCacheKey(_owner, _uid));
      if (raw != null) {
        _cache = GradeSnapshot.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    final now = ref.read(gradeClockProvider)();
    final currentCache = _cache;
    final examCache = currentCache?.education == 'graduate'
        ? null
        : readExamCache(prefs, _owner, _uid, currentSemester(now));
    final examDates =
        examCache != null &&
            (currentCache?.exams == null ||
                examCache.at.isAfter(currentCache!.exams!.at))
        ? AcademicExamDates(
            term: examCache.term,
            at: examCache.at,
            dates: examCache.exams
                .map((e) => e.date)
                .whereType<DateTime>()
                .toSet()
                .toList(),
          )
        : currentCache?.education == 'graduate'
        ? null
        : currentCache?.exams;
    final fresh =
        currentCache != null &&
        currentCache.version >= 2 &&
        now.difference(currentCache.at) < const Duration(days: 1) &&
        !now.isBefore(currentCache.at);
    AppLog.event(
      'grades.cache',
      fields: {
        'scope': scope == null ? 'owner' : 'assist',
        'status': currentCache == null
            ? 'miss'
            : fresh
            ? 'fresh'
            : 'stale',
        if (currentCache != null) 'version': currentCache.version,
        if (currentCache != null)
          'ageSeconds': now.difference(currentCache.at).inSeconds,
      },
    );
    if (fresh) return currentCache;
    if (currentCache != null) {
      // Start after build publishes the cached data; navigation must not wait
      // for the academic login / redirect chain to finish.
      unawaited(
        Future<void>(() async {
          if (revision != _revision) return;
          if (!gradeReleaseWindow(now, exams: examDates)) {
            AppLog.event(
              'grades.refresh.skipped',
              fields: {
                'scope': scope == null ? 'owner' : 'assist',
                'reason': 'outside_grade_release_window',
              },
            );
            return;
          }
          try {
            await refresh();
          } catch (_) {
            if (revision != _revision) return;
            warning = '暂时无法更新，显示本地缓存';
            state = AsyncData(currentCache);
          }
        }),
      );
      return currentCache;
    }
    return _fetch(revision);
  }

  Future<GradeSnapshot> _fetch(int revision) async {
    final owner = _owner, uid = _uid, cache = _cache;
    final selected = ref.read(selectedRollcallAccountProvider);
    final access = await ref.read(academicIdentityResolverProvider)(uid);
    if (access == null) {
      throw AcademicLoginRequired(
        uid == owner ? '请重新登录账号以连接教务' : '请重新导入该协助账号以连接教务',
      );
    }
    Future<bool> current() async =>
        revision == _revision &&
        ref.read(authControllerProvider).profile?.id == owner &&
        ref.read(selectedRollcallAccountProvider) == selected &&
        await access.isCurrent();
    if (!await current()) throw StateError('账号已切换');
    final now = ref.read(gradeClockProvider)();
    final recent =
        cache != null && cache.version >= 2 && useRecentGrades(cache, now);
    final attempts = await SharedPreferences.getInstance();
    final attemptKey = 'grade_attempt_${owner}_$uid';
    final last = attempts.getInt(attemptKey);
    if (last != null &&
        now.millisecondsSinceEpoch - last <
            const Duration(seconds: 15).inMilliseconds) {
      throw const FormatException('请稍后再更新成绩');
    }
    if (!await current()) throw StateError('账号已切换');
    await attempts.setInt(attemptKey, now.millisecondsSinceEpoch);
    final reader = ref.read(gradeReaderProvider)();
    reader.session.identityGuard = current;
    final result = await reader.fetch(
      uid,
      username: access.username,
      password: access.password,
      sso: access.sso,
      recent: recent,
    );
    if (!await current()) throw StateError('账号已切换');
    final fresh = result.rows.map(GradeRecord.new).toList();
    final next = GradeSnapshot(
      at: now,
      term: currentSemester(now),
      education: result.education,
      exams: result.exams ?? cache?.exams,
      records: recent && !result.complete
          ? mergeRecentGrades(cache.records, fresh, result.replacedTerms)
          : fresh,
    );
    final prefs = await SharedPreferences.getInstance();
    if (!await current()) throw StateError('账号已切换');
    if (!await prefs.setString(
      gradeCacheKey(owner, uid),
      jsonEncode(next.toJson()),
    )) {
      throw StateError('成绩缓存未能保存');
    }
    _cache = next;
    warning = null;
    return next;
  }

  Future<void> refresh() async {
    if (state.isLoading && !state.hasValue) {
      await future;
      return;
    }
    if (_flight != null) {
      await _flight;
      return;
    }
    final revision = _revision;
    final next = _flight = _fetch(revision);
    try {
      final result = await next;
      if (revision == _revision) state = AsyncData(result);
    } finally {
      if (revision == _revision) _flight = null;
    }
  }
}
