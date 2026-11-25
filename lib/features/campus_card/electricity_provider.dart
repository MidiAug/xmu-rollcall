import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'campus_card_providers.dart';
import 'electricity_client.dart';
export 'electricity_client.dart';

String electricityCacheKey(BrowserIdentity v) =>
    'campus_electricity_v1_${v.ownerId}_${v.userId}';
final electricityClientFactoryProvider = Provider<ElectricityClient Function()>(
  (ref) => ElectricityClient.new,
);
final cachedElectricityProvider =
    FutureProvider.autoDispose<Map<CardElectricRoomKind, ElectricReading>>((
      ref,
    ) async {
      final identity = ref.watch(browserIdentityProvider);
      final p = await SharedPreferences.getInstance();
      try {
        final raw = p.getString(electricityCacheKey(identity));
        if (raw == null) return {};
        final data = cardMap(raw);
        return {
          for (final kind in CardElectricRoomKind.values)
            if (data[kind.name] != null)
              kind: ElectricReading.fromJson(cardMap(data[kind.name])),
        };
      } on FormatException {
        return {};
      }
    });
final electricityProvider =
    AsyncNotifierProvider.autoDispose<
      ElectricityNotifier,
      Map<CardElectricRoomKind, ElectricReading>
    >(ElectricityNotifier.new);

class ElectricityNotifier
    extends
        AutoDisposeAsyncNotifier<Map<CardElectricRoomKind, ElectricReading>> {
  int _revision = 0;
  Future<void>? _flight;
  DateTime? _attempt;
  late BrowserIdentity _identity;
  String? warning;
  bool updating = false;
  bool _current(int r) =>
      r == _revision && ref.read(browserIdentityProvider) == _identity;
  @override
  Future<Map<CardElectricRoomKind, ElectricReading>> build() async {
    final r = ++_revision;
    _identity = ref.watch(browserIdentityProvider);
    ref.watch(campusCardRoomRevisionProvider);
    ref.onDispose(() => _revision++);
    _flight = null;
    _attempt = null;
    warning = null;
    updating = false;
    if (_identity.userId == null) return {};
    final cached = await ref.read(cachedElectricityProvider.future);
    if (!_current(r)) throw StateError('账号已切换');
    final rooms = await ref
        .read(campusCardInfoProvider.notifier)
        .savedElectricRooms();
    if (!_current(r)) throw StateError('账号已切换');
    AppLog.event(
      'electricity.restore',
      fields: {'roomCount': rooms.length, 'cachedCount': cached.length},
    );
    if (rooms.isEmpty) {
      warning = '请先选择个人宿舍以查询电费';
      return {};
    }
    final valid = <CardElectricRoomKind, ElectricReading>{};
    for (final entry in cached.entries) {
      final room = rooms[entry.key];
      if (room != null &&
          room.id == entry.value.room.id &&
          room.building.id == entry.value.room.building.id &&
          room.area.id == entry.value.room.area.id) {
        valid[entry.key] = entry.value;
      }
    }
    if (valid.isNotEmpty) {
      if (valid.length != rooms.length ||
          valid.values.any(
            (v) =>
                DateTime.now().difference(v.checkedAt) >=
                const Duration(minutes: 5),
          )) {
        unawaited(
          Future<void>(() async {
            if (_current(r)) await refresh();
          }),
        );
      }
      return valid;
    }
    return _fetch(r, rooms);
  }

  Future<Map<CardElectricRoomKind, ElectricReading>> _fetch(
    int r,
    Map<CardElectricRoomKind, CardElectricRoom> rooms,
  ) async {
    final c = ref.read(electricityClientFactoryProvider)();
    c.identityGuard = () async => _current(r);
    final result = <CardElectricRoomKind, ElectricReading>{};
    try {
      for (final entry in rooms.entries) {
        result[entry.key] = await c.read(entry.value);
      }
      if (!_current(r)) throw StateError('账号已切换');
      final p = await SharedPreferences.getInstance();
      if (!_current(r)) throw StateError('账号已切换');
      if (result.isNotEmpty) {
        await p.setString(
          electricityCacheKey(_identity),
          jsonEncode({
            for (final e in result.entries) e.key.name: e.value.toJson(),
          }),
        );
        ref.invalidate(cachedElectricityProvider);
      }
      AppLog.event(
        'electricity.query.success',
        fields: {'readingCount': result.length},
      );
      return result;
    } catch (e) {
      AppLog.event(
        'electricity.query.failed',
        level: 'W',
        fields: {
          'errorType': e.runtimeType.toString(),
          'roomCount': rooms.length,
        },
      );
      rethrow;
    } finally {
      c.close();
    }
  }

  Future<void> refresh() =>
      _flight ??= _refresh().whenComplete(() => _flight = null);
  Future<void> _refresh() async {
    if (_attempt != null &&
        DateTime.now().difference(_attempt!) < const Duration(seconds: 15)) {
      return;
    }
    _attempt = DateTime.now();
    final r = _revision;
    final previous = state.valueOrNull;
    updating = true;
    warning = null;
    state = const AsyncLoading<Map<CardElectricRoomKind, ElectricReading>>()
        .copyWithPrevious(state);
    try {
      final rooms = await ref
          .read(campusCardInfoProvider.notifier)
          .savedElectricRooms();
      if (!_current(r)) return;
      if (rooms.isEmpty) {
        warning = '请先选择个人宿舍以查询电费';
        AppLog.event('electricity.rooms.missing');
        state = const AsyncData({});
        return;
      }
      final value = await _fetch(r, rooms);
      if (_current(r)) state = AsyncData(value);
    } catch (e, st) {
      if (!_current(r)) return;
      warning = e is FormatException ? e.message : '电费查询未完成，请稍后重试';
      state = previous == null ? AsyncError(e, st) : AsyncData(previous);
    } finally {
      if (_current(r)) updating = false;
    }
  }
}
