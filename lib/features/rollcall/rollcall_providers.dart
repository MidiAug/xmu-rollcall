import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

final rollcallRepositoryProvider = Provider<RollcallRepository>((ref) {
  return RollcallRepository(
    http: ref.watch(tronHttpClientProvider),
    identity: ref.watch(deviceIdentityProvider),
  );
});

final activeRollcallsProvider =
    AsyncNotifierProvider<ActiveRollcallsNotifier, List<RollcallItem>>(
  ActiveRollcallsNotifier.new,
);

class ActiveRollcallsNotifier extends AsyncNotifier<List<RollcallItem>> {
  @override
  Future<List<RollcallItem>> build() {
    return ref.read(rollcallRepositoryProvider).fetchActive();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(rollcallRepositoryProvider).fetchActive(),
    );
  }
}

final historyProvider =
    StateNotifierProvider<HistoryController, List<RollcallHistoryEntry>>((ref) {
  return HistoryController();
});

class HistoryController extends StateNotifier<List<RollcallHistoryEntry>> {
  HistoryController() : super(const []) {
    _load();
  }

  static const _key = 'local_rollcall_history';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .whereType<Map>()
          .map((e) => RollcallHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}
  }

  Future<void> add(RollcallHistoryEntry entry) async {
    state = [entry, ...state].take(100).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    state = const [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
