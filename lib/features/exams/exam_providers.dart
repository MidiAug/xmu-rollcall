import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'academic_exam_reader.dart';
import 'exam_models.dart';
import 'exam_cache.dart';

final examClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final examReaderProvider = Provider<AcademicExamReader Function()>((ref) {
  final create = ref.watch(academicSessionFactoryProvider);
  return () => AcademicExamReader(create());
});
final examSnapshotProvider =
    AsyncNotifierProvider.autoDispose<ExamNotifier, ExamSnapshot>(
      ExamNotifier.new,
    );

class ExamNotifier extends AutoDisposeAsyncNotifier<ExamSnapshot> {
  int _revision = 0;
  late int _owner, _uid;
  ExamSnapshot? _cache;
  Future<ExamSnapshot>? _flight;
  bool updating = false;
  String? warning;

  @override
  Future<ExamSnapshot> build() async {
    final revision = ++_revision;
    ref.onDispose(() => _revision++);
    final auth = ref.watch(authControllerProvider);
    final selected = ref.watch(selectedRollcallAccountProvider);
    if (!auth.isSignedIn || auth.profile == null) {
      throw const FormatException('请先登录');
    }
    _owner = auth.profile!.id;
    _uid = selected ?? _owner;
    _cache = null;
    _flight = null;
    warning = null;
    updating = false;
    final prefs = await SharedPreferences.getInstance();
    if (revision != _revision) throw StateError('账号已切换');
    final now = ref.read(examClockProvider)();
    final cache = _cache = readExamCache(
      prefs,
      _owner,
      _uid,
      currentSemester(now),
    );
    if (cache == null) {
      final pending = _flight = _fetch(revision, manual: false);
      try {
        return await pending;
      } finally {
        if (revision == _revision) _flight = null;
      }
    }
    // Publish local data before resolving credentials or contacting JW.
    unawaited(
      Future<void>(() async {
        if (revision != _revision) return;
        await checkForUpdates();
      }),
    );
    return cache;
  }

  Future<void> checkForUpdates() async {
    final cache = _cache;
    if (cache == null ||
        !examRefreshDue(cache, ref.read(examClockProvider)())) {
      return;
    }
    try {
      await refresh(manual: false);
    } catch (_) {
      /* warning retains the cache */
    }
  }

  Future<ExamSnapshot> _fetch(int revision, {required bool manual}) async {
    final owner = _owner, uid = _uid;
    final selected = ref.read(selectedRollcallAccountProvider);
    bool selectedCurrent() =>
        revision == _revision &&
        ref.read(authControllerProvider).profile?.id == owner &&
        ref.read(selectedRollcallAccountProvider) == selected;
    final prefs = await SharedPreferences.getInstance();
    if (!selectedCurrent()) throw StateError('账号已切换');
    final now = ref.read(examClockProvider)();
    final term = currentSemester(now);
    final key = examCacheKey(owner, uid, term);
    final last = prefs.getInt('${key}_attempt');
    final failed = prefs.getInt('${key}_failure');
    final stamp = now.millisecondsSinceEpoch;
    if (last != null &&
        stamp - last < const Duration(seconds: 15).inMilliseconds) {
      throw const FormatException('请间隔15秒再更新考试安排');
    }
    if (!manual &&
        failed != null &&
        stamp - failed < const Duration(minutes: 30).inMilliseconds) {
      throw const FormatException('上次更新失败，稍后自动重试；可手动更新');
    }
    // Throttle locally before looking up credentials or opening an IDS session.
    await prefs.setInt('${key}_attempt', stamp);
    final access = await ref.read(academicIdentityResolverProvider)(uid);
    if (!selectedCurrent()) throw StateError('账号已切换');
    if (access == null) {
      throw AcademicLoginRequired(
        uid == owner ? '请重新登录账号以连接教务' : '请重新导入该协助账号以连接教务',
      );
    }
    Future<bool> current() async =>
        selectedCurrent() && await access.isCurrent();
    if (!await current()) throw StateError('账号已切换');
    final reader = ref.read(examReaderProvider)();
    reader.session.identityGuard = current;
    try {
      final next = await reader.fetch(
        uid,
        term: term,
        at: now,
        username: access.username,
        password: access.password,
        sso: access.sso,
      );
      if (!await current()) throw StateError('账号已切换');
      if (next.term != term) throw const FormatException('考试学期不一致');
      if (!await prefs.setString(key, jsonEncode(next.toJson()))) {
        throw StateError('考试缓存未能保存');
      }
      if (!await current()) throw StateError('账号已切换');
      await prefs.remove('${key}_failure');
      _cache = next;
      warning = null;
      return next;
    } catch (_) {
      if (await current()) await prefs.setInt('${key}_failure', stamp);
      rethrow;
    }
  }

  Future<void> refresh({bool manual = true}) async {
    if (state.isLoading && !state.hasValue) {
      await future;
      return;
    }
    if (_flight != null) {
      await _flight;
      return;
    }
    final revision = _revision;
    updating = true;
    warning = null;
    state = _cache != null ? AsyncData(_cache!) : const AsyncLoading();
    final next = _flight = _fetch(revision, manual: manual);
    try {
      final result = await next;
      if (revision == _revision) state = AsyncData(result);
    } catch (error, stack) {
      if (revision == _revision) {
        warning = error is FormatException ? error.message : '暂时无法更新，显示本地缓存';
        state = _cache != null ? AsyncData(_cache!) : AsyncError(error, stack);
      }
      rethrow;
    } finally {
      if (revision == _revision) {
        _flight = null;
        updating = false;
        if (_cache case final cache?) state = AsyncData(cache);
      }
    }
  }
}
