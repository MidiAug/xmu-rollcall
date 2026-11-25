import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'campus_card_client.dart';
export 'campus_card_models.dart';

String campusCardCacheKey(BrowserIdentity identity) =>
    'campus_card_v1_${identity.ownerId}_${identity.userId}';
final campusCardClientFactoryProvider = Provider<CampusCardClient Function()>(
  (ref) =>
      () => CampusCardClient(Dio()),
);
final campusCardClientProvider = Provider.autoDispose<CampusCardClient>((ref) {
  ref.watch(browserIdentityProvider);
  final client = ref.watch(campusCardClientFactoryProvider)();
  ref.onDispose(client.close);
  return client;
});
final campusCardInfoProvider =
    AsyncNotifierProvider.autoDispose<CampusCardNotifier, CampusCardInfo>(
      CampusCardNotifier.new,
    );
final campusCardCachedInfoProvider =
    FutureProvider.autoDispose<CampusCardInfo?>((ref) async {
      final identity = ref.watch(browserIdentityProvider);
      if (identity.userId == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(campusCardCacheKey(identity));
      if (raw == null) return null;
      try {
        return CampusCardInfo.fromCardJson(cardMap(cardMap(raw)['card']));
      } catch (_) {
        return null;
      }
    });

class CampusCardNotifier extends AutoDisposeAsyncNotifier<CampusCardInfo> {
  late BrowserIdentity _identity;
  late CampusCardClient _client;
  int _revision = 0;
  Future<void>? _flight;
  DateTime? fetchedAt, _attempt;
  bool updating = false;
  String? warning;
  bool _current(int revision) =>
      revision == _revision && ref.read(browserIdentityProvider) == _identity;
  @override
  Future<CampusCardInfo> build() async {
    final revision = ++_revision;
    _identity = ref.watch(browserIdentityProvider);
    _client = ref.watch(campusCardClientProvider);
    _flight = null;
    updating = false;
    warning = null;
    fetchedAt = null;
    _attempt = null;
    ref.onDispose(() => _revision++);
    if (_identity.userId == null) throw const CampusCardException('请先登录');
    final prefs = await SharedPreferences.getInstance();
    if (!_current(revision)) throw StateError('账号已切换');
    final raw = prefs.getString(campusCardCacheKey(_identity));
    if (raw != null) {
      try {
        final data = cardMap(raw);
        final info = CampusCardInfo.fromCardJson(cardMap(data['card']));
        fetchedAt = DateTime.parse(data['fetchedAt'] as String);
        if (DateTime.now().difference(fetchedAt!) >=
            const Duration(minutes: 5)) {
          unawaited(
            Future<void>(() async {
              if (_current(revision)) await refresh();
            }),
          );
        }
        return info;
      } catch (_) {
        fetchedAt = null;
      }
    }
    _attempt = DateTime.now();
    return _fetch(revision);
  }

  // These are user-confirmed destinations, never claimed as school dorm bindings.
  String get _roomsKey =>
      'campus_card_rooms_v1_${_identity.ownerId}_${_identity.userId}';
  Future<Map<CardElectricRoomKind, CardElectricRoom>>
  savedElectricRooms() async {
    final revision = _revision;
    final prefs = await SharedPreferences.getInstance();
    if (!_current(revision)) throw StateError('账号已切换');
    final raw = prefs.getString(_roomsKey);
    if (raw == null) return {};
    try {
      final data = cardMap(raw);
      return {
        for (final kind in CardElectricRoomKind.values)
          if (data[kind.name] != null)
            kind: CardElectricRoom.fromJson(cardMap(data[kind.name])),
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> rememberElectricRoom(
    CardElectricRoomKind kind,
    CardElectricRoom room,
  ) async {
    final revision = _revision;
    final key = _roomsKey;
    final previous = await savedElectricRooms();
    previous[kind] = room;
    final prefs = await SharedPreferences.getInstance();
    if (!_current(revision)) throw StateError('账号已切换');
    if (!await prefs.setString(
      key,
      jsonEncode({
        for (final entry in previous.entries)
          entry.key.name: entry.value.toJson(),
      }),
    )) {
      throw const CampusCardException('宿舍记录未能保存，请重试');
    }
  }

  Future<CampusCardInfo> _connected(int revision, {bool force = false}) async {
    final access = await ref.read(academicIdentityResolverProvider)(
      _identity.userId!,
    );
    if (!_current(revision)) throw StateError('账号已切换');
    if (access == null || access.username == null) {
      throw const CampusCardException('请重新登录所选账号以连接校园卡');
    }
    _client.identityGuard = () async =>
        _current(revision) && await access.isCurrent();
    return _client.fetch(studentNo: access.username!, force: force);
  }

  Future<CampusCardInfo> account() async {
    final revision = _revision;
    final client = _client;
    final info = await _connected(revision);
    if (!_current(revision) || !await client.identityGuard!()) {
      throw StateError('账号已切换');
    }
    return info;
  }

  Future<T> run<T>(Future<T> Function(CampusCardClient client) action) async {
    final revision = _revision;
    final client = _client;
    await _connected(revision);
    if (!_current(revision)) throw StateError('账号已切换');
    final result = await action(client);
    if (!_current(revision) || !await client.identityGuard!()) {
      throw StateError('账号已切换');
    }
    return result;
  }

  Future<CampusCardInfo> _fetch(int revision) async {
    final info = await _connected(revision, force: true);
    final identity = _identity;
    final stamp = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    if (!_current(revision) || !await _client.identityGuard!()) {
      throw StateError('账号已切换');
    }
    if (!await prefs.setString(
      campusCardCacheKey(identity),
      jsonEncode({'card': info.toJson(), 'fetchedAt': stamp.toIso8601String()}),
    )) {
      throw const CampusCardException('校园卡数据未能保存，请稍后重试');
    }
    fetchedAt = stamp;
    ref.invalidate(campusCardCachedInfoProvider);
    return info;
  }

  Future<void> refresh({bool afterMutation = false}) {
    if (_flight != null) return _flight!;
    if (!afterMutation &&
        _attempt != null &&
        DateTime.now().difference(_attempt!) < const Duration(seconds: 15)) {
      warning = '请间隔15秒再更新';
      if (state.valueOrNull != null) state = AsyncData(state.requireValue);
      return Future.value();
    }
    final revision = _revision;
    return _flight = _update(revision).whenComplete(() {
      if (_current(revision)) _flight = null;
    });
  }

  Future<void> _update(int revision) async {
    final previous = state.valueOrNull;
    _attempt = DateTime.now();
    updating = true;
    warning = null;
    state = const AsyncLoading<CampusCardInfo>().copyWithPrevious(state);
    try {
      final next = await _fetch(revision);
      if (_current(revision)) {
        updating = false;
        state = AsyncData(next);
      }
    } catch (e, st) {
      if (!_current(revision)) return;
      updating = false;
      warning = e is FormatException ? e.message : '校园卡更新失败，请稍后重试';
      state = previous == null ? AsyncError(e, st) : AsyncData(previous);
    }
  }
}
