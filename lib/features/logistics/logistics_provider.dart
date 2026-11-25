import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'logistics_client.dart';
import 'logistics_models.dart';
export 'logistics_models.dart';

String logisticsCacheKey(BrowserIdentity identity) =>
    'logistics_v1_${identity.ownerId}_${identity.userId}';
final logisticsClientFactoryProvider = Provider<LogisticsClient Function()>(
  (ref) => LogisticsClient.new,
);
final logisticsProvider =
    AsyncNotifierProvider.autoDispose<LogisticsNotifier, LogisticsSnapshot>(
      LogisticsNotifier.new,
    );

class LogisticsNotifier extends AutoDisposeAsyncNotifier<LogisticsSnapshot> {
  int _revision = 0;
  late BrowserIdentity _identity;
  LogisticsClient? _client;
  Future<void>? _flight;
  DateTime? _attempt;
  bool updating = false;
  String? warning;
  bool _current(int revision) =>
      revision == _revision && ref.read(browserIdentityProvider) == _identity;

  @override
  Future<LogisticsSnapshot> build() async {
    final revision = ++_revision;
    final old = _client;
    old?.dio.close(force: true);
    _client = null;
    _flight = null;
    _attempt = null;
    updating = false;
    warning = null;
    ref.onDispose(() {
      _revision++;
      _client?.dio.close(force: true);
    });
    _identity = ref.watch(browserIdentityProvider);
    if (_identity.userId == null) throw const FormatException('请先登录');
    final prefs = await SharedPreferences.getInstance();
    if (!_current(revision)) throw StateError('账号已切换');
    final raw = prefs.getString(logisticsCacheKey(_identity));
    if (raw != null) {
      try {
        final snapshot = LogisticsSnapshot.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (DateTime.now().difference(snapshot.fetchedAt) >=
            const Duration(minutes: 5)) {
          unawaited(
            Future<void>(() async {
              if (_current(revision)) await refresh();
            }),
          );
        }
        return snapshot;
      } catch (_) {
        /* Re-read an invalid cache without replacing it on failure. */
      }
    }
    _attempt = DateTime.now();
    return _fetch(revision);
  }

  Future<LogisticsSnapshot> _fetch(
    int revision, {
    LogisticsSnapshot? previous,
  }) async {
    final identity = _identity;
    final access = await ref.read(academicIdentityResolverProvider)(
      identity.userId!,
    );
    if (!_current(revision)) throw StateError('账号已切换');
    if (access == null || access.username == null) {
      throw const FormatException('请重新登录所选账号以连接后勤');
    }
    final client = _client ??= ref.read(logisticsClientFactoryProvider)();
    client.identityGuard = () async =>
        _current(revision) && await access.isCurrent();
    await client.connect(
      username: access.username!,
      password: access.password,
      sso: access.sso,
    );
    final page = previous == null ? 1 : previous.page + 1;
    final list = await client.repairs(page);
    final messages = previous == null ? await client.messages() : null;
    final rows = (list['rows'] as List)
        .map((e) => LogisticsRepair(e as Map<String, dynamic>))
        .toList();
    if (rows.isEmpty &&
        page > 1 &&
        (list['total'] as num) > previous!.repairs.length) {
      throw const FormatException('后勤分页结果不完整，请重新更新');
    }
    final result = LogisticsSnapshot(
      repairs: [...?previous?.repairs, ...rows],
      messages: messages == null
          ? previous!.messages
          : (messages['rows'] as List)
                .map((e) => LogisticsMessage(e as Map<String, dynamic>))
                .toList(),
      total: (list['total'] as num).toInt(),
      page: page,
      fetchedAt: previous?.fetchedAt ?? DateTime.now(),
    );
    if (!_current(revision) || !await access.isCurrent()) {
      throw StateError('账号已切换');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!_current(revision)) throw StateError('账号已切换');
    if (!await prefs.setString(
      logisticsCacheKey(identity),
      jsonEncode(result.toJson()),
    )) {
      throw const FormatException('后勤数据未能保存，请稍后重试');
    }
    return result;
  }

  Future<void> refresh({bool more = false}) {
    if (_flight != null) return _flight!;
    final revision = _revision;
    return _flight = _update(more).whenComplete(() {
      if (revision == _revision) _flight = null;
    });
  }

  Future<void> _update(bool more) async {
    final revision = _revision;
    final old = state.valueOrNull;
    if (more && (old == null || old.repairs.length >= old.total)) return;
    if (!more &&
        _attempt != null &&
        DateTime.now().difference(_attempt!) < const Duration(seconds: 15)) {
      warning = '请间隔15秒再更新';
      state = old == null
          ? AsyncError(FormatException(warning!), StackTrace.current)
          : AsyncData(old);
      return;
    }
    _attempt = DateTime.now();
    updating = true;
    warning = null;
    state = const AsyncLoading<LogisticsSnapshot>().copyWithPrevious(state);
    try {
      final next = await _fetch(revision, previous: more ? old : null);
      if (_current(revision)) {
        updating = false;
        state = AsyncData(next);
      }
    } catch (error, stack) {
      if (!_current(revision)) return;
      updating = false;
      warning = error is FormatException ? error.message : '后勤更新失败，请稍后重试';
      state = old == null ? AsyncError(error, stack) : AsyncData(old);
    }
  }
}
