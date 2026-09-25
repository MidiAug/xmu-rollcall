import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/core/cache/history_candidates.dart';
import 'package:xmu_rollcall/core/cache/session_memory.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository_providers.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/rollcall/session_prior.dart';

export 'package:xmu_rollcall/core/cache/session_memory.dart'
    show seenInProgressCourseIdsProvider;
export 'package:xmu_rollcall/features/rollcall/rollcall_repository_providers.dart';

/// Family: `null` = owner active list; otherwise that assist userId.
final activeRollcallsProvider = AsyncNotifierProvider.family<
    ActiveRollcallsNotifier, List<RollcallItem>, int?>(
  ActiveRollcallsNotifier.new,
);

class ActiveRollcallsNotifier
    extends FamilyAsyncNotifier<List<RollcallItem>, int?> {
  int? _boundOwnerUserId;

  @override
  Future<List<RollcallItem>> build(int? assistUserId) async {
    if (assistUserId == null) {
      final auth = ref.watch(authControllerProvider);
      if (!auth.isSignedIn || auth.profile == null || auth.profile!.id == 0) {
        _boundOwnerUserId = null;
        return const [];
      }
      _boundOwnerUserId = auth.profile!.id;
    }
    final items = await ref
        .read(rollcallRepositoryForProvider(assistUserId))
        .fetchActiveEnriched();
    if (assistUserId == null) {
      _noteSeenCourses(items);
    }
    return items;
  }

  void _noteSeenCourses(List<RollcallItem> items) {
    final ids = <String>{
      for (final i in items)
        if ((i.courseId ?? '').trim().isNotEmpty) i.courseId!.trim(),
    };
    if (ids.isEmpty) return;
    final prev = ref.read(seenInProgressCourseIdsProvider);
    ref.read(seenInProgressCourseIdsProvider.notifier).state = {...prev, ...ids};
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    final started = DateTime.now();
    final ownerUid = _boundOwnerUserId;
    AppLog.event(
      'rollcall.list.refresh',
      fields: {
        'session': arg == null ? 'owner' : 'assist',
        if (arg != null) 'assistUserId': arg,
      },
    );
    final next = await AsyncValue.guard(
      () => ref
          .read(rollcallRepositoryForProvider(arg))
          .fetchActiveEnriched(),
    );
    // Write-back guard for owner live list.
    if (arg == null &&
        ownerUid != null &&
        ref.read(authControllerProvider).profile?.id != ownerUid) {
      return;
    }
    final ms = DateTime.now().difference(started).inMilliseconds;
    if (!next.hasValue) {
      AppLog.event(
        'rollcall.list.refresh',
        level: 'W',
        fields: {
          'ok': false,
          'durationMs': ms,
          'errorType': next.error?.runtimeType.toString() ?? 'unknown',
          'session': arg == null ? 'owner' : 'assist',
        },
      );
      state = next;
      return;
    }
    final incoming = next.requireValue;
    if (arg == null) _noteSeenCourses(incoming);
    AppLog.event(
      'rollcall.list.refresh',
      fields: {
        'ok': true,
        'count': incoming.length,
        'durationMs': ms,
        'session': arg == null ? 'owner' : 'assist',
      },
    );
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

  /// Debug-only: replace owner active list without hitting the network.
  void debugSeed(List<RollcallItem> items) {
    assert(kDebugMode, 'debugSeed is debug-only');
    if (!kDebugMode) return;
    state = AsyncData(List<RollcallItem>.of(items));
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
  final uid = ref.watch(authControllerProvider.select((s) => s.profile?.id));
  return HistoryController(userId: uid);
});

class HistoryController extends StateNotifier<List<RollcallHistoryEntry>> {
  HistoryController({this.userId}) : super(const []) {
    _load();
  }

  final int? userId;

  static const _legacyKey = 'local_rollcall_history';

  String? get _key {
    final id = userId;
    if (id == null || id == 0) return null;
    return 'local_rollcall_history_$id';
  }

  Future<void> _load() async {
    final key = _key;
    if (key == null) {
      state = const [];
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      // Migrate legacy global key once.
      final legacy = prefs.getString(_legacyKey);
      if (legacy != null && legacy.isNotEmpty) {
        await prefs.setString(key, legacy);
        await prefs.remove(_legacyKey);
        raw = legacy;
      }
    }
    if (raw == null || raw.isEmpty) {
      state = const [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .whereType<Map>()
          .map((e) => RollcallHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      state = const [];
    }
  }

  Future<void> add(RollcallHistoryEntry entry) async {
    final key = _key;
    if (key == null) return;
    state = [entry, ...state].take(100).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    state = const [];
    final key = _key;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

final courseHistoryProvider =
    AsyncNotifierProvider<CourseHistoryNotifier, List<CourseRollcallRecord>>(
  CourseHistoryNotifier.new,
);

class CourseHistoryNotifier extends AsyncNotifier<List<CourseRollcallRecord>> {
  int? _boundUserId;
  Future<void>? _inFlightEnsure;
  final _courseSnaps = <String, CourseRollcallsSnapshot>{};

  @override
  Future<List<CourseRollcallRecord>> build() async {
    ref.keepAlive();
    final auth = ref.watch(authControllerProvider);
    final profile = auth.profile;
    if (!auth.isSignedIn || profile == null || profile.id == 0) {
      _boundUserId = null;
      _courseSnaps.clear();
      return const [];
    }
    _boundUserId = profile.id;
    return _loadFromDisk(profile.id);
  }

  Future<List<CourseRollcallRecord>> _loadFromDisk(int userId) async {
    final catalog = await ref.read(courseCatalogProvider.future);
    final titles = catalog?.titlesById ?? <String, String>{};
    _courseSnaps.clear();

    // Prefer catalog course ids; also surface any orphan disks via titles keys.
    final ids = <String>{...titles.keys};
    if (ids.isEmpty && catalog == null) {
      // Cold: trigger catalog sticky miss fetch via provider.
      return const [];
    }

    for (final id in ids) {
      final snap = await CourseRollcallsStore.read(userId, id);
      if (snap != null) {
        _courseSnaps[id] = snap.courseTitle.isEmpty && titles[id] != null
            ? snap.copyWith(courseTitle: titles[id])
            : snap;
      } else if (titles.containsKey(id)) {
        _courseSnaps[id] = CourseRollcallsSnapshot(
          courseId: id,
          courseTitle: titles[id] ?? '',
        );
      }
    }

    // Migrate legacy package cache once into per-course (best-effort).
    await _migrateLegacyPackage(userId, titles);

    return _flatten();
  }

  Future<void> _migrateLegacyPackage(
    int userId,
    Map<String, String> titles,
  ) async {
    final legacy = await JsonDiskCache.readList('course_history_$userId');
    if (legacy == null || legacy.items.isEmpty) return;
    final byCourse = <String, List<CourseRollcallRecord>>{};
    for (final m in legacy.items) {
      final r = CourseRollcallRecord.fromJson(m);
      if (r.isPlaceholder && r.signedStatus.contains('???')) {
        byCourse.putIfAbsent(r.courseId, () => []);
        continue;
      }
      if (r.isPlaceholder) continue;
      byCourse.putIfAbsent(r.courseId, () => []).add(r);
    }
    for (final e in byCourse.entries) {
      if (_courseSnaps[e.key]?.lastSuccessfulFetch != null) continue;
      final title = titles[e.key] ??
          (e.value.isNotEmpty ? e.value.first.courseTitle : '');
      final snap = await CourseRollcallsStore.writeSuccess(
        userId: userId,
        courseId: e.key,
        courseTitle: title,
        records: e.value,
        at: legacy.fetchedAt,
      );
      _courseSnaps[e.key] = snap;
    }
    await JsonDiskCache.remove('course_history_$userId');
  }

  List<CourseRollcallRecord> _flatten() {
    final rows = <CourseRollcallRecord>[
      for (final snap in _courseSnaps.values)
        ...CourseRollcallsStore.toHistoryRows(snap),
    ];
    rows.sort((a, b) {
      final at = a.rollcallTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.rollcallTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return rows;
  }

  Future<void> ensureFresh({
    EnsureFreshReason reason = EnsureFreshReason.appear,
  }) async {
    final existing = _inFlightEnsure;
    if (existing != null) {
      await existing;
      return;
    }
    final future = _ensureFreshBody(reason);
    _inFlightEnsure = future;
    try {
      await future;
    } finally {
      if (identical(_inFlightEnsure, future)) _inFlightEnsure = null;
    }
  }

  Future<void> _ensureFreshBody(EnsureFreshReason reason) async {
    final uid = _boundUserId ?? ref.read(authControllerProvider).profile?.id;
    if (uid == null || uid == 0) return;

    // Ensure catalog available (sticky; may network once).
    await ref.read(courseCatalogProvider.notifier).ensureFresh(
          reason: EnsureFreshReason.appear,
        );
    if (_boundUserId != uid) return;

    final catalog = ref.read(courseCatalogProvider).valueOrNull;
    final titles = catalog?.titlesById ?? <String, String>{};
    for (final id in titles.keys) {
      _courseSnaps.putIfAbsent(
        id,
        () => CourseRollcallsSnapshot(
          courseId: id,
          courseTitle: titles[id] ?? '',
        ),
      );
    }

    // Cold (no successful course fetch yet): full scan once.
    // Appear / pull otherwise: incremental candidates only (R-35).
    final cold = historyNeedsFullScan(_courseSnaps.values);
    final List<HistoryCandidate> candidates;
    if (cold) {
      final ids = titles.keys.isNotEmpty ? titles.keys : _courseSnaps.keys;
      candidates = [
        for (final id in ids.take(CachePolicy.updateAllMaxCourses))
          HistoryCandidate(
            courseId: id,
            courseTitle: titles[id] ?? _courseSnaps[id]?.courseTitle ?? '',
            reason: 'cold_${reason.name}',
          ),
      ];
    } else {
      final seen = ref.read(seenInProgressCourseIdsProvider);
      candidates = selectHistoryCandidates(
        courseTitles: titles.isNotEmpty
            ? titles
            : {
                for (final e in _courseSnaps.entries) e.key: e.value.courseTitle,
              },
        disks: Map<String, CourseRollcallsSnapshot?>.from(_courseSnaps),
        seenInProgressCourseIds: seen,
        timetablesByCourse: catalog?.timetablesByCourse ?? const {},
        now: DateTime.now(),
      );
    }

    if (candidates.isEmpty) {
      if (_boundUserId == uid) state = AsyncData(_flatten());
      return;
    }

    AppLog.event(
      'history.ensureFresh',
      fields: {
        'reason': reason.name,
        'cold': cold,
        'candidates': candidates.length,
      },
    );

    for (final c in candidates) {
      if (_boundUserId != uid) return;
      await _fetchOne(uid, c.courseId, c.courseTitle);
      await Future<void>.delayed(CachePolicy.courseFetchGap);
    }
    if (_boundUserId == uid) {
      state = AsyncData(_flatten());
    }
  }

  Future<void> _fetchOne(int userId, String courseId, String title) async {
    final previous = _courseSnaps[courseId];
    try {
      final data =
          await ref.read(rollcallRepositoryProvider).fetchCourseRollcalls(
                courseId: courseId,
                studentId: userId,
                courseTitle: title,
              );
      if (_boundUserId != userId) return;
      final truncated = data.length >= 100;
      final snap = await CourseRollcallsStore.writeSuccess(
        userId: userId,
        courseId: courseId,
        courseTitle: title.isNotEmpty
            ? title
            : (previous?.courseTitle ?? ''),
        records: data,
        truncated: truncated,
      );
      // Drop legacy prior key if present.
      await JsonDiskCache.remove('course_rollcalls_${userId}_$courseId');
      _courseSnaps[courseId] = snap;
    } catch (e) {
      if (_boundUserId != userId) return;
      final snap = await CourseRollcallsStore.writeFailure(
        userId: userId,
        courseId: courseId,
        courseTitle: title,
        error: e,
        previous: previous,
      );
      _courseSnaps[courseId] = snap;
    }
  }

  Future<void> refresh() =>
      ensureFresh(reason: EnsureFreshReason.pullToRefresh);

  Future<void> refreshCourse(String courseId) async {
    final uid = _boundUserId ?? ref.read(authControllerProvider).profile?.id;
    if (uid == null || uid == 0) return;
    final title = _courseSnaps[courseId]?.courseTitle ??
        ref.read(courseCatalogProvider).valueOrNull?.titlesById[courseId] ??
        '';
    await _fetchOne(uid, courseId, title);
    if (_boundUserId == uid) state = AsyncData(_flatten());
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

/// UI model for the session-prior panel under an active rollcall card.
class SessionPriorState {
  const SessionPriorState({
    this.snapshot,
    this.unscoped = false,
    this.nowMinutes,
  });

  final SessionPriorSnapshot? snapshot;
  final bool unscoped;
  final int? nowMinutes;
}

/// Course id ? weekday ? slots from sticky catalog (owner session).
final courseTimetablesProvider =
    Provider<Map<String, Map<int, List<TimetableSlot>>>>((ref) {
  final catalog = ref.watch(courseCatalogProvider).valueOrNull;
  return catalog?.timetablesByCourse ?? const {};
});

/// Session prior for one course (owner only). [courseId] from [RollcallItem.courseId].
final sessionPriorProvider =
    FutureProvider.autoDispose.family<SessionPriorState, String>((ref, courseId) async {
  final profile = ref.watch(authControllerProvider).profile;
  if (profile == null || profile.id == 0) {
    return const SessionPriorState(unscoped: true);
  }
  final cid = courseId.trim();
  if (cid.isEmpty) return const SessionPriorState(unscoped: true);

  final now = DateTime.now();
  // Ensure catalog loaded (sticky).
  await ref.watch(courseCatalogProvider.future);
  if (ref.read(authControllerProvider).profile?.id != profile.id) {
    return const SessionPriorState(unscoped: true);
  }
  final tables = ref.watch(courseTimetablesProvider);
  final byDay = tables[cid];
  final slots = byDay?[now.weekday];
  if (slots == null || slots.isEmpty) {
    return const SessionPriorState(unscoped: true);
  }
  final blocks = splitContiguousBlocks(slots);
  final block = resolveBlock(blocks, now);
  if (block == null) {
    return const SessionPriorState(unscoped: true);
  }

  final history = await _fetchCourseRollcallsCached(
    ref: ref,
    courseId: cid,
    studentId: profile.id,
    courseTitle: ref.read(courseCatalogProvider).valueOrNull?.titlesById[cid] ??
        '',
  );
  if (ref.read(authControllerProvider).profile?.id != profile.id) {
    return const SessionPriorState(unscoped: true);
  }
  final snap = buildSessionPrior(
    block: block,
    weekday: now.weekday,
    history: history,
  );
  return SessionPriorState(
    snapshot: snap,
    nowMinutes: minutesOfDay(now),
  );
});

Future<List<CourseRollcallRecord>> _fetchCourseRollcallsCached({
  required Ref ref,
  required String courseId,
  required int studentId,
  String courseTitle = '',
}) async {
  final existing = await CourseRollcallsStore.read(studentId, courseId);
  if (existing != null &&
      existing.isFresh(CachePolicy.enterSwrFreshFor) &&
      existing.fetchState != CourseRollcallsFetchState.neverChecked) {
    return existing.records;
  }
  try {
    final data =
        await ref.read(rollcallRepositoryProvider).fetchCourseRollcalls(
              courseId: courseId,
              studentId: studentId,
              courseTitle: courseTitle,
            );
    if (ref.read(authControllerProvider).profile?.id != studentId) {
      return data;
    }
    await CourseRollcallsStore.writeSuccess(
      userId: studentId,
      courseId: courseId,
      courseTitle: courseTitle,
      records: data,
      truncated: data.length >= 100,
    );
    await JsonDiskCache.remove('course_rollcalls_${studentId}_$courseId');
    return data;
  } catch (_) {
    if (existing != null) return existing.records;
    rethrow;
  }
}
