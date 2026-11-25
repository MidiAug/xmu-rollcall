import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'classroom_client.dart';
export 'classroom_client.dart';

String classroomCacheKey(BrowserIdentity v) =>
    'classrooms_v1_${v.ownerId}_${v.userId}';
final classroomClientFactoryProvider = Provider<ClassroomClient Function()>(
  (ref) => ClassroomClient.new,
);
final classroomProvider =
    AsyncNotifierProvider.autoDispose<ClassroomNotifier, ClassroomHome>(
      ClassroomNotifier.new,
    );

class ClassroomNotifier extends AutoDisposeAsyncNotifier<ClassroomHome> {
  late BrowserIdentity _identity;
  ClassroomClient? _client;
  int _revision = 0;
  Future<void>? _flight;
  DateTime? _attempt, fetchedAt;
  bool updating = false;
  String? warning;
  bool _current(int r) =>
      r == _revision && ref.read(browserIdentityProvider) == _identity;
  @override
  Future<ClassroomHome> build() async {
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
    final raw = p.getString(classroomCacheKey(_identity));
    if (raw != null) {
      try {
        final v = classroomMap(raw);
        final home = ClassroomHome.fromJson(classroomMap(v['home']));
        fetchedAt = DateTime.parse(v['fetchedAt'] as String);
        if (DateTime.now().difference(fetchedAt!) >=
            const Duration(minutes: 5)) {
          unawaited(
            Future<void>(() async {
              if (_current(r)) await refresh();
            }),
          );
        }
        return home;
      } on FormatException {
        fetchedAt = null;
      }
    }
    _attempt = DateTime.now();
    return _fetch(r);
  }

  Future<ClassroomClient> _connected(int r) async {
    final access = await ref.read(academicIdentityResolverProvider)(
      _identity.userId!,
    );
    if (!_current(r)) throw StateError('账号已切换');
    if (access == null || access.username == null) {
      throw const FormatException('请重新登录所选账号以连接厦大教室');
    }
    final c = _client ??= ref.read(classroomClientFactoryProvider)();
    c.identityGuard = () async => _current(r) && await access.isCurrent();
    await c.connect(
      username: access.username!,
      password: access.password,
      sso: access.sso,
    );
    if (!_current(r) || !await access.isCurrent()) throw StateError('账号已切换');
    return c;
  }

  Future<T> run<T>(Future<T> Function(ClassroomClient) call) async {
    final r = _revision;
    final c = await _connected(r);
    final result = await call(c);
    if (!_current(r)) throw StateError('账号已切换');
    return result;
  }

  Future<ClassroomHome> _fetch(int r) async {
    final c = await _connected(r);
    final home = await c.home();
    final p = await SharedPreferences.getInstance();
    if (!_current(r)) throw StateError('账号已切换');
    final stamp = DateTime.now();
    await p.setString(
      classroomCacheKey(_identity),
      jsonEncode({'home': home.toJson(), 'fetchedAt': stamp.toIso8601String()}),
    );
    fetchedAt = stamp;
    return home;
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
    final previous = state.valueOrNull;
    updating = true;
    warning = null;
    state = const AsyncLoading<ClassroomHome>().copyWithPrevious(state);
    try {
      final v = await _fetch(r);
      if (_current(r)) state = AsyncData(v);
    } catch (e, st) {
      if (_current(r)) {
        warning = e is FormatException ? e.message : '教室更新失败，请稍后重试';
        state = previous == null ? AsyncError(e, st) : AsyncData(previous);
      }
    } finally {
      if (_current(r)) updating = false;
    }
  }
}
