import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/schedule/academic_client.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'grade_models.dart';

String gradeCacheKey(int owner, int uid) => 'grades_v1_${owner}_$uid';
final gradeClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final gradeClientProvider = Provider<AcademicClient Function()>(
  (ref) =>
      () => AcademicClient(store: ref.read(secureStoreProvider)),
);
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
    if (_cache != null &&
        now.difference(_cache!.at) < const Duration(days: 1) &&
        !now.isBefore(_cache!.at)) {
      return _cache!;
    }
    try {
      return await _fetch(revision);
    } catch (_) {
      if (revision != _revision) rethrow;
      if (_cache != null) {
        warning = '暂时无法更新，显示本地缓存';
        return _cache!;
      }
      rethrow;
    }
  }

  Future<GradeSnapshot> _fetch(int revision) async {
    final owner = _owner, uid = _uid, cache = _cache;
    final selected = ref.read(selectedRollcallAccountProvider);
    final ownerClient = uid == owner ? ref.read(tronHttpClientProvider) : null;
    final ownerRevision = ownerClient?.sessionRevision;
    final store = ref.read(secureStoreProvider);
    final access = await ref
        .read(academicSyncProvider)
        .resolveIdentity
        ?.call(uid);
    if (uid != owner && access == null) {
      throw const AcademicLoginRequired('请重新导入该协助账号以连接教务');
    }
    Future<bool> current() async =>
        revision == _revision &&
        ref.read(authControllerProvider).profile?.id == owner &&
        await store.read(SecureStore.keyUserId) == '$owner' &&
        (ownerClient == null || ownerClient.sessionRevision == ownerRevision) &&
        ref.read(selectedRollcallAccountProvider) == selected &&
        (access == null || await access.isCurrent());
    if (!await current()) throw StateError('账号已切换');
    final client = ref.read(gradeClientProvider)()..identityGuard = current;
    final now = ref.read(gradeClockProvider)();
    final recent = useRecentGrades(cache, now);
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
    final result = await client.fetchGrades(
      uid,
      username:
          access?.username ??
          (uid == owner ? await store.read(SecureStore.keyLastUsername) : null),
      password:
          access?.password ??
          (uid == owner
              ? await store.read(SecureStore.keyOwnerPassword)
              : null),
      sso:
          access?.sso ??
          (uid == owner ? ref.read(tronHttpClientProvider).cookieJar : null),
      recent: recent,
    );
    if (!await current()) throw StateError('账号已切换');
    final fresh = result.rows.map(GradeRecord.new).toList();
    final next = GradeSnapshot(
      at: now,
      term: currentSemester(now),
      records: recent
          ? mergeRecentGrades(cache!.records, fresh, result.replacedTerms)
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
