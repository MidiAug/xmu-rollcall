import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/session/session_key.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

/// [assistUserId] null = owner session; otherwise assist jar + roster deviceId.
final rollcallRepositoryForProvider =
    Provider.family<RollcallRepository, int?>((ref, assistUserId) {
  final registry = ref.watch(sessionClientRegistryProvider);
  final key = assistUserId == null
      ? SessionKey.owner
      : SessionKey.assist(assistUserId);
  String? deviceOverride;
  if (assistUserId != null) {
    for (final e in ref.watch(assistControllerProvider).identities) {
      if (e.userId == assistUserId) {
        deviceOverride = e.deviceId;
        break;
      }
    }
  }
  return RollcallRepository(
    http: registry.forKey(key),
    identity: ref.watch(deviceIdentityProvider),
    deviceIdOverride: deviceOverride,
  );
});

final rollcallRepositoryProvider = Provider<RollcallRepository>((ref) {
  return ref.watch(rollcallRepositoryForProvider(null));
});

/// Family: `null` = owner active list; otherwise that assist userId.
final activeRollcallsProvider = AsyncNotifierProvider.family<
    ActiveRollcallsNotifier, List<RollcallItem>, int?>(
  ActiveRollcallsNotifier.new,
);

class ActiveRollcallsNotifier
    extends FamilyAsyncNotifier<List<RollcallItem>, int?> {
  @override
  Future<List<RollcallItem>> build(int? assistUserId) {
    return ref
        .read(rollcallRepositoryForProvider(assistUserId))
        .fetchActiveEnriched();
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    final next = await AsyncValue.guard(
      () => ref
          .read(rollcallRepositoryForProvider(arg))
          .fetchActiveEnriched(),
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

  void patchItem(RollcallItem updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final item in current)
        if (item.rollcallId == updated.rollcallId) updated else item,
    ]);
  }
}

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
  static const ttl = Duration(minutes: 10);

  DateTime? _fetchedAt;
  var _revalidateScheduled = false;

  String? get _cacheSuffix {
    final id = ref.read(authControllerProvider).profile?.id;
    if (id == null || id == 0) return null;
    return 'course_history_$id';
  }

  @override
  Future<List<CourseRollcallRecord>> build() async {
    ref.keepAlive();
    final suffix = _cacheSuffix;
    if (suffix != null) {
      final snap = await JsonDiskCache.readList(suffix);
      if (snap != null) {
        _fetchedAt = snap.fetchedAt;
        final items = [
          for (final m in snap.items) CourseRollcallRecord.fromJson(m),
        ];
        if (!snap.isFresh(ttl)) {
          _scheduleRevalidate();
        }
        return items;
      }
    }
    return _fetchAndPersist();
  }

  void _scheduleRevalidate() {
    if (_revalidateScheduled) return;
    _revalidateScheduled = true;
    Future.microtask(() async {
      try {
        await _revalidate();
      } finally {
        _revalidateScheduled = false;
      }
    });
  }

  Future<void> _revalidate() async {
    final previous = state.valueOrNull;
    final next = await AsyncValue.guard(_fetchAndPersist);
    if (next.hasValue) {
      final incoming = next.requireValue;
      if (previous == null) {
        state = AsyncData(incoming);
      } else {
        state = AsyncData(mergeCourseHistory(previous, incoming));
      }
    } else if (previous == null) {
      state = next;
    }
  }

  Future<List<CourseRollcallRecord>> _fetchAndPersist() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null || profile.id == 0) {
      throw StateError('请先登录');
    }
    final data = await ref.read(rollcallRepositoryProvider).fetchCourseHistory(
          studentId: profile.id,
        );
    _fetchedAt = DateTime.now();
    final suffix = _cacheSuffix;
    if (suffix != null) {
      await JsonDiskCache.writeList(
        suffix,
        [for (final e in data) e.toJson()],
        fetchedAt: _fetchedAt,
      );
    }
    return data;
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    final next = await AsyncValue.guard(_fetchAndPersist);
    if (!next.hasValue) {
      if (previous == null) state = next;
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
