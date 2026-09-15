import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
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
    return ref.read(rollcallRepositoryProvider).fetchActiveEnriched();
  }

  Future<void> refresh() async {
    // Keep previous list visible; RefreshIndicator / header button own the spinner.
    // Merge so unchanged rows keep identity; only inserts/updates replace.
    final previous = state.valueOrNull;
    final next = await AsyncValue.guard(
      () => ref.read(rollcallRepositoryProvider).fetchActiveEnriched(),
    );
    if (!next.hasValue) {
      state = next;
      return;
    }
    final incoming = next.requireValue;
    if (previous == null) {
      state = AsyncData(incoming);
      return;
    }
    state = AsyncData(mergeActiveRollcalls(previous, incoming));
  }

  /// Replace one row after local answer without full refresh.
  void patchItem(RollcallItem updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final item in current)
        if (item.rollcallId == updated.rollcallId) updated else item,
    ]);
  }
}

/// Prefer previous instances when fields match — avoids full list rebuild.
@visibleForTesting
List<RollcallItem> mergeActiveRollcalls(
  List<RollcallItem> previous,
  List<RollcallItem> incoming,
) {
  bool same(RollcallItem a, RollcallItem b) =>
      a.rollcallId == b.rollcallId &&
      a.courseTitle == b.courseTitle &&
      a.createdByName == b.createdByName &&
      a.departmentName == b.departmentName &&
      a.type == b.type &&
      a.status == b.status &&
      a.rollcallStatus == b.rollcallStatus &&
      a.isExpired == b.isExpired &&
      a.scored == b.scored &&
      a.numberCode == b.numberCode &&
      a.numberCodeError == b.numberCodeError;

  final prevById = {for (final r in previous) r.rollcallId: r};
  final merged = <RollcallItem>[
    for (final r in incoming)
      if (prevById[r.rollcallId] != null && same(prevById[r.rollcallId]!, r))
        prevById[r.rollcallId]!
      else
        r,
  ];

  if (merged.length == previous.length) {
    var allSame = true;
    for (var i = 0; i < merged.length; i++) {
      if (!identical(merged[i], previous[i])) {
        allSame = false;
        break;
      }
    }
    if (allSame) return previous;
  }
  return merged;
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

final courseHistoryProvider =
    AsyncNotifierProvider<CourseHistoryNotifier, List<CourseRollcallRecord>>(
  CourseHistoryNotifier.new,
);

class CourseHistoryNotifier extends AsyncNotifier<List<CourseRollcallRecord>> {
  @override
  Future<List<CourseRollcallRecord>> build() async {
    return _load();
  }

  Future<List<CourseRollcallRecord>> _load() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null || profile.id == 0) {
      throw StateError('\u8bf7\u5148\u767b\u5f55');
    }
    return ref.read(rollcallRepositoryProvider).fetchCourseHistory(
          studentId: profile.id,
        );
  }

  Future<void> refresh() async {
    // Keep previous list visible; RefreshIndicator owns the in-flight spinner.
    // Merge so unchanged rows keep identity; only inserts/updates replace.
    final previous = state.valueOrNull;
    final next = await AsyncValue.guard(_load);
    if (!next.hasValue) {
      state = next;
      return;
    }
    final incoming = next.requireValue;
    if (previous == null) {
      state = AsyncData(incoming);
      return;
    }
    state = AsyncData(mergeCourseHistory(previous, incoming));
  }
}

/// Prefer previous instances when fields match — avoids full list rebuild.
@visibleForTesting
List<CourseRollcallRecord> mergeCourseHistory(
  List<CourseRollcallRecord> previous,
  List<CourseRollcallRecord> incoming,
) {
  String key(CourseRollcallRecord r) =>
      r.isPlaceholder ? 'c:${r.courseId}' : 'r:${r.rollcallId}';

  bool same(CourseRollcallRecord a, CourseRollcallRecord b) =>
      a.courseId == b.courseId &&
      a.courseTitle == b.courseTitle &&
      a.rollcallId == b.rollcallId &&
      a.typeLabel == b.typeLabel &&
      a.signedStatus == b.signedStatus &&
      a.platformStatus == b.platformStatus &&
      a.detail == b.detail &&
      a.rollcallTime == b.rollcallTime;

  final prevByKey = {for (final r in previous) key(r): r};
  final merged = <CourseRollcallRecord>[
    for (final r in incoming)
      if (prevByKey[key(r)] != null && same(prevByKey[key(r)]!, r))
        prevByKey[key(r)]!
      else
        r,
  ];

  if (merged.length == previous.length) {
    var allSame = true;
    for (var i = 0; i < merged.length; i++) {
      if (!identical(merged[i], previous[i])) {
        allSame = false;
        break;
      }
    }
    if (allSame) return previous;
  }
  return merged;
}
