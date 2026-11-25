import 'package:xmu_rollcall/core/cache/cache_revisions.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'lecture_client.dart';
export 'lecture_client.dart';

String lectureCacheKey(BrowserIdentity v) =>
    'lectures_v1_${v.ownerId}_${v.userId}';
String lectureSessionKey(BrowserIdentity v) =>
    'lecture_session_v1_${v.ownerId}_${v.userId}';
final lectureClientFactoryProvider = Provider<LectureClient Function()>(
  (ref) => LectureClient.new,
);
final lectureProvider =
    AsyncNotifierProvider.autoDispose<LectureNotifier, LecturePage>(
      LectureNotifier.new,
    );

class LectureNotifier extends AutoDisposeAsyncNotifier<LecturePage> {
  late BrowserIdentity _identity;
  LectureClient? _client;
  int _revision = 0;
  Future<void>? _flight;
  DateTime? _attempt, fetchedAt;
  String? warning;
  bool updating = false;
  bool _current(int r) =>
      r == _revision && ref.read(browserIdentityProvider) == _identity;
  @override
  Future<LecturePage> build() async {
    final r = ++_revision;
    _client?.close();
    _client = null;
    _identity = ref.watch(browserIdentityProvider);
    _flight = null;
    _attempt = null;
    fetchedAt = null;
    warning = null;
    updating = false;
    ref.onDispose(() {
      _revision++;
      _client?.close();
    });
    if (_identity.userId == null) throw const FormatException('请先登录');
    final p = await SharedPreferences.getInstance();
    if (!_current(r)) throw StateError('账号已切换');
    final raw = p.getString(lectureCacheKey(_identity));
    if (raw != null) {
      try {
        final v = lectureMap(raw);
        final cached = LecturePage.fromCache(lectureMap(v['page']));
        fetchedAt = DateTime.parse(v['fetchedAt'] as String);
        if (DateTime.now().difference(fetchedAt!) >=
            const Duration(minutes: 5)) {
          unawaited(
            Future<void>(() async {
              if (_current(r)) await refresh();
            }),
          );
        }
        return cached;
      } on FormatException {
        fetchedAt = null;
      } on TypeError {
        fetchedAt = null;
      }
    }
    _attempt = DateTime.now();
    return _fetch(r);
  }

  Future<LectureClient> _connected(int r) async {
    final access = await ref.read(academicIdentityResolverProvider)(
      _identity.userId!,
    );
    if (!_current(r)) throw StateError('账号已切换');
    if (access?.username == null) throw const FormatException('请重新登录当前账号');
    final c = _client ??= ref.read(lectureClientFactoryProvider)();
    c.identityGuard = () async => _current(r) && await access!.isCurrent();
    final key = await ref
        .read(secureStoreProvider)
        .read(lectureSessionKey(_identity));
    if (!_current(r)) throw StateError('账号已切换');
    await c.connect(username: access!.username!, deviceKey: key);
    return c;
  }

  Future<void> acceptAuthorization(String deviceKey) async {
    final r = _revision;
    final access = await ref.read(academicIdentityResolverProvider)(
      _identity.userId!,
    );
    if (!_current(r)) throw StateError('账号已切换');
    if (access?.username == null) throw const FormatException('请重新登录当前账号');
    final c = ref.read(lectureClientFactoryProvider)();
    c.identityGuard = () async => _current(r) && await access!.isCurrent();
    try {
      await c.connect(username: access!.username!, deviceKey: deviceKey);
      if (!_current(r) || !await access.isCurrent()) throw StateError('账号已切换');
      await ref
          .read(secureStoreProvider)
          .write(lectureSessionKey(_identity), deviceKey);
      if (!_current(r)) throw StateError('账号已切换');
      _client?.close();
      _client = null;
      _attempt = null;
    } finally {
      c.close();
    }
    await refresh();
  }

  Future<T> run<T>(Future<T> Function(LectureClient) action) async {
    final r = _revision;
    final c = await _connected(r);
    final result = await action(c);
    if (!_current(r)) throw StateError('账号已切换');
    return result;
  }

  Future<LecturePage> _fetch(int r) async {
    final c = await _connected(r);
    final result = await c.attended();
    final p = await SharedPreferences.getInstance();
    if (!_current(r)) throw StateError('账号已切换');
    final stamp = DateTime.now();
    await p.setString(
      lectureCacheKey(_identity),
      jsonEncode({
        'fetchedAt': stamp.toIso8601String(),
        'page': result.toJson(),
      }),
    );
    if (!_current(r)) throw StateError('账号已切换');
    ref.read(lectureCacheRevisionProvider.notifier).state++;
    fetchedAt = stamp;
    return result;
  }

  Future<void> refresh() {
    if (_flight != null) return _flight!;
    final r = _revision;
    return _flight = _refresh(r).whenComplete(() {
      if (_current(r)) _flight = null;
    });
  }

  Future<void> _refresh(int r) async {
    if (_attempt != null &&
        DateTime.now().difference(_attempt!) < const Duration(seconds: 15)) {
      warning = '请间隔15秒再更新';
      if (state.valueOrNull != null) state = AsyncData(state.requireValue);
      return;
    }
    _attempt = DateTime.now();
    updating = true;
    warning = null;
    final previous = state.valueOrNull;
    state = const AsyncLoading<LecturePage>().copyWithPrevious(state);
    try {
      final next = await _fetch(r);
      if (_current(r)) state = AsyncData(next);
    } catch (e, st) {
      if (_current(r)) {
        warning = e is FormatException ? e.message : '讲座更新失败，请稍后重试';
        state = previous == null ? AsyncError(e, st) : AsyncData(previous);
      }
    } finally {
      if (_current(r)) updating = false;
    }
  }
}
