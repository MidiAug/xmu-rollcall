import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/network/request_failure.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/core/cache/history_candidates.dart';
import 'package:xmu_rollcall/core/cache/session_memory.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository_providers.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/rollcall/session_prior.dart';
import 'package:xmu_rollcall/features/rollcall/active_rollcall_cache.dart';

export 'package:xmu_rollcall/core/cache/session_memory.dart'
    show seenInProgressCourseIdsProvider;
export 'package:xmu_rollcall/features/rollcall/rollcall_repository_providers.dart';

final activeRollcallClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final courseHistoryClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Family: `null` = owner active list; otherwise that assist userId.
final activeRollcallsProvider =
    AsyncNotifierProvider.family<
      ActiveRollcallsNotifier,
      List<RollcallItem>,
      int?
    >(ActiveRollcallsNotifier.new);

class ActiveRollcallsNotifier
    extends FamilyAsyncNotifier<List<RollcallItem>, int?> {
  int? _boundOwnerUserId;
  int _revision = 0;
  CancelToken? _requestToken;
  Future<void>? _refreshing;
  String? _codeCacheKey;
  final _numberCodes = <int, String>{};
  final _observedActivityStates = <int, String>{};
  int _codeRevision = 0;
  int _queuedCodeRevision = 0;
  Future<void> _codeWrites = Future.value();
  Future<void> _activeWrites = Future.value();
  DateTime? _lastAppearCheckAt;
  DateTime? lastUpdatedAt;
  String? get _activeCacheKey => _boundOwnerUserId == null
      ? null
      : 'active_rollcalls_${_boundOwnerUserId}_${arg ?? _boundOwnerUserId}';

  @override
  Future<List<RollcallItem>> build(int? assistUserId) async {
    final revision = ++_revision;
    ref.onDispose(() {
      _revision++;
      _requestToken?.cancel('页面已关闭');
    });
    ref.watch(
      authControllerProvider.select((s) => (s.isSignedIn, s.profile?.id)),
    );
    final auth = ref.read(authControllerProvider);
    if (_boundOwnerUserId != auth.profile?.id || !auth.isSignedIn) {
      _observedActivityStates.clear();
    }
    if (!auth.isSignedIn || auth.profile == null || auth.profile!.id == 0) {
      _boundOwnerUserId = null;
      _codeCacheKey = null;
      _numberCodes.clear();
      _queuedCodeRevision = ++_codeRevision;
      lastUpdatedAt = null;
      _lastAppearCheckAt = null;
      return const [];
    }
    final previous = _boundOwnerUserId == auth.profile!.id
        ? state.valueOrNull ?? const <RollcallItem>[]
        : const <RollcallItem>[];
    _boundOwnerUserId = auth.profile!.id;
    final now = ref.read(activeRollcallClockProvider)();
    final disk = await JsonDiskCache.readList(_activeCacheKey!);
    if (revision != _revision) return state.valueOrNull ?? const [];
    final cached = restoreActiveRollcalls(disk, now);
    final cacheKey =
        'number_codes_${auth.profile!.id}_${assistUserId ?? auth.profile!.id}';
    Future<void>? restoreCodes;
    if (_codeCacheKey != cacheKey) {
      _codeCacheKey = cacheKey;
      _numberCodes.clear();
      _queuedCodeRevision = ++_codeRevision;
      restoreCodes = _restoreNumberCodes(cacheKey);
    }
    // Restore before enrichment so signed activities can reuse persisted codes
    // without querying their details again on every launch or refresh.
    await restoreCodes;
    if (revision != _revision) return state.valueOrNull ?? const [];
    await ref.read(detectionWindowProvider.notifier).ready;
    if (revision != _revision) return state.valueOrNull ?? const [];
    if (!ref
        .read(detectionWindowProvider)!
        .allows(ref.read(activeRollcallClockProvider)())) {
      lastUpdatedAt = disk?.fetchedAt;
      return _retainNumberCodes(cached.isNotEmpty ? cached : previous);
    }
    _lastAppearCheckAt = now;
    if (cached.isNotEmpty) {
      lastUpdatedAt = disk!.fetchedAt;
      Future<void>(() async {
        if (revision == _revision) await refresh();
      });
      return _retainNumberCodes(cached);
    }
    final token = _requestToken = CancelToken();
    try {
      final items = await ref
          .read(rollcallRepositoryForProvider(assistUserId))
          .fetchActiveEnriched(
            cancelToken: token,
            cachedNumberCodes: Map.unmodifiable(_numberCodes),
          );
      if (revision != _revision) return state.valueOrNull ?? const [];
      lastUpdatedAt = ref.read(activeRollcallClockProvider)();
      _noteSeenCourses(items);
      final merged = mergeActiveRollcalls(previous, _retainNumberCodes(items));
      _persistActive(merged);
      return merged;
    } on DetectionWindowClosed {
      if (revision != _revision) return state.valueOrNull ?? const [];
      return previous;
    } catch (_) {
      if (revision != _revision) return state.valueOrNull ?? const [];
      rethrow;
    }
  }

  void _persistActive(List<RollcallItem> items) {
    final key = _activeCacheKey;
    final uid = arg ?? _boundOwnerUserId;
    final revision = _revision;
    final at = lastUpdatedAt ?? ref.read(activeRollcallClockProvider)();
    if (key == null || uid == null) return;
    _activeWrites = _activeWrites
        .then((_) async {
          final catalog = await CourseCatalogStore.read(uid);
          if (revision != _revision) return;
          await JsonDiskCache.writeList(
            key,
            cacheActiveRollcalls(items, catalog, at),
            fetchedAt: at,
          );
        })
        .catchError((Object _) {});
  }

  /// Short entry cooldown; a cached form is shown only in its original class.
  Future<void> ensureFreshOnAppear() async {
    try {
      await future;
    } catch (_) {}
    if (_boundOwnerUserId == null) return;
    final now = ref.read(activeRollcallClockProvider)();
    if (_lastAppearCheckAt != null &&
        now.difference(_lastAppearCheckAt!) < const Duration(seconds: 15)) {
      return;
    }
    _lastAppearCheckAt = now;
    final revision = _revision;
    final previous = state.valueOrNull;
    if (previous != null && lastUpdatedAt != null) {
      final catalog = await CourseCatalogStore.read(arg ?? _boundOwnerUserId!);
      if (revision != _revision) return;
      state = AsyncData(
        restoreActiveRollcalls(
          DiskCacheSnapshot(
            fetchedAt: lastUpdatedAt!,
            items: cacheActiveRollcalls(previous, catalog, lastUpdatedAt!),
          ),
          now,
        ),
      );
    }
    await refresh();
  }

  Future<void> _restoreNumberCodes(String key) async {
    try {
      final cached = await JsonDiskCache.readList(key);
      if (key != _codeCacheKey ||
          cached == null ||
          !cached.isFresh(const Duration(days: 7))) {
        AppLog.event(
          'rollcall.code_cache.restore',
          fields: {
            'cacheKey': key,
            'count': 0,
            'reason': cached == null ? 'missing' : 'expired_or_superseded',
          },
        );
        return;
      }
      for (final entry in cached.items) {
        final id = entry['id'];
        final code = entry['code'];
        if (id is int && code is String && code.isNotEmpty) {
          _numberCodes.putIfAbsent(id, () => code);
        }
      }
      AppLog.event(
        'rollcall.code_cache.restore',
        fields: {
          'cacheKey': key,
          'count': _numberCodes.length,
          'reason': 'restored',
        },
      );
    } catch (error) {
      AppLog.event(
        'rollcall.code_cache.error',
        level: 'W',
        fields: {
          'cacheKey': key,
          'operation': 'read',
          'errorType': error.runtimeType.toString(),
        },
      );
      // Cache failures must not prevent fetching the current activities.
    }
  }

  List<RollcallItem> _retainNumberCodes(List<RollcallItem> items) {
    var changed = false;
    final result = [
      for (final item in items)
        if (item.isNumber &&
            item.numberCode?.isNotEmpty != true &&
            _numberCodes.containsKey(item.rollcallId))
          item.copyWith(
            numberCode: _numberCodes[item.rollcallId],
            clearNumberCodeError: true,
          )
        else
          item,
    ];
    for (final item in result) {
      final code = item.numberCode;
      if (item.isNumber &&
          code != null &&
          code.isNotEmpty &&
          _numberCodes[item.rollcallId] != code) {
        _numberCodes.remove(item.rollcallId);
        _numberCodes[item.rollcallId] = code;
        changed = true;
      }
    }
    while (_numberCodes.length > 100) {
      _numberCodes.remove(_numberCodes.keys.first);
    }
    final key = _codeCacheKey;
    if (changed) _codeRevision++;
    if (_codeRevision != _queuedCodeRevision && key != null) {
      final version = _queuedCodeRevision = _codeRevision;
      final entries = [
        for (final e in _numberCodes.entries) {'id': e.key, 'code': e.value},
      ];
      _codeWrites = _codeWrites
          .then((_) async {
            await JsonDiskCache.writeList(key, entries);
            AppLog.event(
              'rollcall.code_cache.write',
              fields: {
                'cacheKey': key,
                'count': entries.length,
                'rollcallIds': entries.take(20).map((e) => e['id']).toList(),
              },
            );
          })
          .catchError((Object error) {
            // A later refresh can retry a failed disk write even when the
            // number itself is unchanged. Do not overwrite a newer queue gate.
            if (_codeCacheKey == key && _queuedCodeRevision == version) {
              _queuedCodeRevision = version - 1;
            }
            AppLog.event(
              'rollcall.code_cache.error',
              level: 'W',
              fields: {
                'cacheKey': key,
                'operation': 'write',
                'errorType': error.runtimeType.toString(),
              },
            );
          });
    }
    return result;
  }

  void _noteSeenCourses(List<RollcallItem> items) {
    final ids = <String>{
      for (final i in items)
        if ((i.courseId ?? '').trim().isNotEmpty &&
            _observedActivityStates[i.rollcallId] !=
                '${i.courseId}:${i.status}:${i.isExpired}')
          i.courseId!.trim(),
    };
    for (final item in items) {
      _observedActivityStates[item.rollcallId] =
          '${item.courseId}:${item.status}:${item.isExpired}';
    }
    if (ids.isEmpty) return;
    final prev = ref.read(
      (arg == null
          ? seenInProgressCourseIdsProvider
          : importedSeenCourseIdsProvider(arg!)),
    );
    ref
        .read(
          (arg == null
                  ? seenInProgressCourseIdsProvider
                  : importedSeenCourseIdsProvider(arg!))
              .notifier,
        )
        .state = {
      ...prev,
      ...ids,
    };
  }

  Future<void> refresh() {
    if (_refreshing != null) return _refreshing!;
    final future = _refresh();
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
  }

  Future<void> _refresh() async {
    final beforeLoad = _revision;
    await ref.read(detectionWindowProvider.notifier).ready;
    if (beforeLoad != _revision) return;
    if (!ref
        .read(detectionWindowProvider)!
        .allows(ref.read(activeRollcallClockProvider)())) {
      return;
    }
    final revision = ++_revision;
    _requestToken?.cancel('刷新已替换');
    final token = _requestToken = CancelToken();
    final previous = state.valueOrNull;
    _lastAppearCheckAt = ref.read(activeRollcallClockProvider)();
    if (previous != null) {
      state = const AsyncLoading<List<RollcallItem>>().copyWithPrevious(
        AsyncData(previous),
      );
    }
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
          .fetchActiveEnriched(
            cancelToken: token,
            cachedNumberCodes: Map.unmodifiable(_numberCodes),
          ),
    );
    if (revision != _revision) return;
    // Write-back guard for owner live list.
    if (arg == null &&
        ownerUid != null &&
        ref.read(authControllerProvider).profile?.id != ownerUid) {
      return;
    }
    final ms = DateTime.now().difference(started).inMilliseconds;
    if (next.error is DetectionWindowClosed) {
      state = AsyncData(previous ?? const []);
      return;
    }
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
      state = previous == null
          ? next
          : next.copyWithPrevious(AsyncData(previous));
      if (arg == null && isSessionExpired(next.error)) {
        ref.read(authControllerProvider.notifier).expireSession();
      }
      return;
    }
    final incoming = _retainNumberCodes(next.requireValue);
    lastUpdatedAt = ref.read(activeRollcallClockProvider)();
    _noteSeenCourses(incoming);
    final typeCounts = <String, int>{};
    final statusCounts = <String, int>{};
    final ids = <int>[];
    for (final item in incoming) {
      final t = item.type.name;
      typeCounts[t] = (typeCounts[t] ?? 0) + 1;
      final st = item.status.isEmpty ? '(empty)' : item.status;
      statusCounts[st] = (statusCounts[st] ?? 0) + 1;
      if (ids.length < 20) ids.add(item.rollcallId);
    }
    final hasUnknown = (typeCounts['unknown'] ?? 0) > 0;
    AppLog.event(
      'rollcall.list.refresh',
      level: hasUnknown ? 'W' : 'I',
      fields: {
        'ok': true,
        'count': incoming.length,
        'durationMs': ms,
        'session': arg == null ? 'owner' : 'assist',
        'typeCounts': typeCounts,
        'statusCounts': statusCounts,
        'ids': ids,
        if (hasUnknown) 'hasUnknownType': true,
      },
    );
    if (previous == null) {
      state = AsyncData(incoming);
      _persistActive(incoming);
      return;
    }
    state = AsyncData(mergeActiveRollcalls(previous, incoming));
    _persistActive(state.requireValue);
  }

  /// Publish discovery or local answer results; only a fetched snapshot advances
  /// the server-check timestamp. Attendance updates must not look like discovery.
  void applyMonitorItems(List<RollcallItem> items, {DateTime? fetchedAt}) {
    final revision = ++_revision;
    final ownerUid = _boundOwnerUserId;
    _requestToken?.cancel('已收到更新的检测结果');
    final token = _requestToken = CancelToken();
    final incoming = mergeActiveRollcalls(
      state.valueOrNull ?? const [],
      _retainNumberCodes(items),
    );
    if (fetchedAt != null) {
      lastUpdatedAt = fetchedAt;
      _lastAppearCheckAt = fetchedAt;
    }
    _noteSeenCourses(incoming);
    state = AsyncData(
      mergeActiveRollcalls(state.valueOrNull ?? const [], incoming),
    );
    AppLog.event(
      'rollcall.monitor_snapshot.applied',
      fields: {
        'session': arg == null ? 'owner' : 'assist',
        'count': incoming.length,
        'numberCodes': incoming
            .where((i) => i.isNumber && i.numberCode?.isNotEmpty == true)
            .length,
        'source': fetchedAt == null ? 'answer_feedback' : 'discovery',
        'rollcallIds': incoming.take(20).map((i) => i.rollcallId).toList(),
        if (fetchedAt != null) 'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      },
    );
    _persistActive(state.requireValue);
    if (!incoming.any(
      (i) => i.isNumber && !i.isExpired && i.numberCode?.isNotEmpty != true,
    )) {
      return;
    }
    unawaited(() async {
      try {
        final enriched = await ref
            .read(rollcallRepositoryForProvider(arg))
            .enrichActive(incoming, cancelToken: token);
        if (revision != _revision ||
            ref.read(authControllerProvider).profile?.id != ownerUid) {
          return;
        }
        state = AsyncData(
          mergeActiveRollcalls(
            state.valueOrNull ?? const [],
            _retainNumberCodes(enriched),
          ),
        );
        _persistActive(state.requireValue);
      } catch (_) {
        // A superseding snapshot cancels enrichment without replacing newer data.
      }
    }());
  }

  void patchItem(RollcallItem updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    _noteSeenCourses([updated]);
    state = AsyncData(
      _retainNumberCodes([
        for (final item in current)
          if (item.rollcallId == updated.rollcallId) updated else item,
      ]),
    );
    _persistActive(state.requireValue);
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
  RollcallItem retainCode(RollcallItem item) {
    final old = prevById[item.rollcallId];
    if (item.isNumber &&
        old?.isNumber == true &&
        item.numberCode?.isNotEmpty != true &&
        old!.numberCode?.isNotEmpty == true) {
      return item.copyWith(numberCode: old.numberCode);
    }
    return item;
  }

  final merged = <RollcallItem>[
    for (final r in incoming.map(retainCode))
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
      final uid = ref.watch(
        authControllerProvider.select((s) => s.profile?.id),
      );
      return HistoryController(userId: uid);
    });

class HistoryController extends StateNotifier<List<RollcallHistoryEntry>> {
  HistoryController({this.userId, this.migrateLegacy = true})
    : super(const []) {
    _loaded = _load();
  }

  final int? userId;
  final bool migrateLegacy;
  late final Future<void> _loaded;

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
    if (!mounted) return;
    var raw = prefs.getString(key);
    if (migrateLegacy && (raw == null || raw.isEmpty)) {
      // Migrate legacy global key once.
      final legacy = prefs.getString(_legacyKey);
      if (legacy != null && legacy.isNotEmpty) {
        await prefs.setString(key, legacy);
        await prefs.remove(_legacyKey);
        raw = legacy;
      }
    }
    if (!mounted) return;
    if (raw == null || raw.isEmpty) {
      state = const [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .whereType<Map>()
          .map(
            (e) => RollcallHistoryEntry.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (_) {
      state = const [];
    }
  }

  Future<void> add(RollcallHistoryEntry entry) async {
    await _loaded;
    if (!mounted) return;
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
    await _loaded;
    if (!mounted) return;
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

final scopedCourseHistoryProvider =
    Provider.family<
      AsyncNotifierProvider<CourseHistoryNotifier, List<CourseRollcallRecord>>,
      int?
    >((ref, id) {
      if (id == null) return courseHistoryProvider;
      return AsyncNotifierProvider<
        CourseHistoryNotifier,
        List<CourseRollcallRecord>
      >(() => CourseHistoryNotifier(assistUserId: id));
    });

final importedSeenCourseIdsProvider = StateProvider.family<Set<String>, int>((
  ref,
  id,
) {
  ref.watch(authControllerProvider.select((a) => a.profile?.id));
  return {};
});

final currentCourseHistoryProvider =
    Provider<AsyncValue<List<CourseRollcallRecord>>>((ref) {
      final scope = ref.watch(selectedRollcallAccountProvider);
      return ref.watch(ref.watch(scopedCourseHistoryProvider(scope)));
    });
final currentHistoryControllerProvider = Provider<CourseHistoryNotifier>((ref) {
  final scope = ref.watch(selectedRollcallAccountProvider);
  return ref.read(ref.watch(scopedCourseHistoryProvider(scope)).notifier);
});
final localHistoryForProvider =
    Provider.family<
      StateNotifierProvider<HistoryController, List<RollcallHistoryEntry>>,
      int?
    >((ref, id) {
      if (id == null) return historyProvider;
      return StateNotifierProvider<
        HistoryController,
        List<RollcallHistoryEntry>
      >((ref) => HistoryController(userId: id, migrateLegacy: false));
    });
final currentLocalHistoryProvider = Provider<List<RollcallHistoryEntry>>((ref) {
  return ref.watch(
    ref.watch(
      localHistoryForProvider(ref.watch(selectedRollcallAccountProvider)),
    ),
  );
});

class CourseHistoryNotifier extends AsyncNotifier<List<CourseRollcallRecord>> {
  CourseHistoryNotifier({this.assistUserId});
  final int? assistUserId;
  AsyncNotifierProvider<CourseCatalogNotifier, CourseCatalogSnapshot?>
  get _catalogProvider => ref.read(scopedCourseCatalogProvider(assistUserId));
  StateProvider<Set<String>> get _seenProvider => assistUserId == null
      ? seenInProgressCourseIdsProvider
      : importedSeenCourseIdsProvider(assistUserId!);
  int? _boundUserId;
  Future<void>? _inFlightEnsure;
  String? _inFlightCourseId;
  EnsureFreshReason _inFlightReason = EnsureFreshReason.appear;
  final _lastCourseAttempts = <String, DateTime>{};
  final _courseSnaps = <String, CourseRollcallsSnapshot>{};
  Set<String> _attendanceCourseIds = {};

  @override
  Future<List<CourseRollcallRecord>> build() async {
    ref.keepAlive();
    final auth = ref.watch(authControllerProvider);
    _lastCourseAttempts.clear();
    _inFlightEnsure = null;
    final profile = auth.profile;
    if (!auth.isSignedIn || profile == null || profile.id == 0) {
      _boundUserId = null;
      _courseSnaps.clear();
      return const [];
    }
    _boundUserId = assistUserId ?? profile.id;
    return _loadFromDisk(_boundUserId!);
  }

  Future<List<CourseRollcallRecord>> _loadFromDisk(int userId) async {
    final catalog = await ref.read(_catalogProvider.future);
    final titles = catalog?.attendanceTitlesById ?? <String, String>{};
    _attendanceCourseIds = titles.keys.toSet();
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
      final title =
          titles[e.key] ??
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
        if (_attendanceCourseIds.contains(snap.courseId))
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
    String? courseId,
  }) {
    final existing = _inFlightEnsure;
    if (existing != null) {
      final coversRequest =
          _inFlightReason != EnsureFreshReason.appear &&
          (_inFlightCourseId == null || _inFlightCourseId == courseId);
      return existing.then<void>((_) async {
        if (reason == EnsureFreshReason.appear || coversRequest) return;
        await ensureFresh(reason: reason, courseId: courseId);
      });
    }
    _inFlightCourseId = courseId;
    _inFlightReason = reason;
    late final Future<void> pending;
    pending = _ensureFreshBody(reason, courseId).whenComplete(() {
      if (identical(_inFlightEnsure, pending)) _inFlightEnsure = null;
    });
    return _inFlightEnsure = pending;
  }

  Future<void> _ensureFreshBody(
    EnsureFreshReason reason,
    String? courseId,
  ) async {
    // Page appearance can race build's disk load. Decide cold/incremental only
    // after the persisted snapshots have been loaded.
    await future;
    final uid =
        _boundUserId ??
        assistUserId ??
        ref.read(authControllerProvider).profile?.id;
    if (uid == null || uid == 0) return;

    // Ensure catalog available (sticky; may network once).
    await ref
        .read(_catalogProvider.notifier)
        .ensureFresh(reason: EnsureFreshReason.appear);
    if (_boundUserId != uid) return;

    final catalog = ref.read(_catalogProvider).valueOrNull;
    final titles = catalog?.attendanceTitlesById ?? <String, String>{};
    _attendanceCourseIds = titles.keys.toSet();
    for (final id in titles.keys) {
      // Session prior shares this store and may have fetched since page build.
      final disk = await CourseRollcallsStore.read(uid, id);
      if (_boundUserId != uid) return;
      if (disk != null) _courseSnaps[id] = disk;
      _courseSnaps.putIfAbsent(
        id,
        () => CourseRollcallsSnapshot(
          courseId: id,
          courseTitle: titles[id] ?? '',
        ),
      );
    }

    // Passive appearance stays incremental; explicit pulls bypass the long TTL
    // within the requested enrolled-course scope, retaining the short request gate.
    final cold = historyNeedsFullScan(_courseSnaps.values);
    final List<HistoryCandidate> candidates;
    final manual = reason != EnsureFreshReason.appear;
    if (cold && !manual) {
      final ids = titles.keys;
      candidates = [
        for (final id in ids.take(CachePolicy.updateAllMaxCourses))
          HistoryCandidate(
            courseId: id,
            courseTitle: titles[id] ?? _courseSnaps[id]?.courseTitle ?? '',
            reason: 'cold_${reason.name}',
          ),
      ];
    } else {
      final seen = ref.read(_seenProvider);
      candidates = selectHistoryCandidates(
        courseTitles: titles,
        disks: Map<String, CourseRollcallsSnapshot?>.from(_courseSnaps),
        seenInProgressCourseIds: seen,
        timetablesByCourse: catalog?.timetablesByCourse ?? const {},
        now: ref.read(courseHistoryClockProvider)(),
        manualRefresh: manual,
        requestedCourseId: courseId,
      );
    }

    final now = ref.read(courseHistoryClockProvider)();
    final eligible = candidates.where((c) {
      final attempted = _lastCourseAttempts[c.courseId];
      return attempted == null ||
          now.difference(attempted) >= CachePolicy.historyRequestGap;
    }).toList();

    AppLog.event(
      'history.ensureFresh',
      fields: {
        'reason': reason.name,
        'userId': uid,
        'scope': 'enrolled_student_courses',
        'cold': cold,
        'candidates': eligible.length,
        'throttled': candidates.length - eligible.length,
        'requestedCourseId': ?courseId,
        'candidateReasons': {for (final c in eligible) c.courseId: c.reason},
      },
    );

    for (final c in eligible) {
      if (_boundUserId != uid) return;
      await _fetchOne(uid, c.courseId, c.courseTitle);
      await Future<void>.delayed(CachePolicy.courseFetchGap);
    }
    if (_boundUserId == uid) {
      state = AsyncData(_flatten());
    }
  }

  Future<void> _fetchOne(int userId, String courseId, String title) async {
    _lastCourseAttempts[courseId] = ref.read(courseHistoryClockProvider)();
    final started = DateTime.now();
    AppLog.event(
      'history.course.start',
      fields: {'userId': userId, 'courseId': courseId},
    );
    final previous = _courseSnaps[courseId];
    // Consume before awaiting so a new live observation during the request
    // remains pending. Failed requests restore the signal for the next refresh.
    final seen = ref.read(_seenProvider);
    final wasPending = seen.contains(courseId);
    if (wasPending) {
      ref.read(_seenProvider.notifier).state = {...seen}..remove(courseId);
    }
    try {
      final data = await ref
          .read(
            assistUserId == null
                ? rollcallRepositoryProvider
                : rollcallRepositoryForProvider(assistUserId),
          )
          .fetchCourseRollcalls(
            courseId: courseId,
            studentId: userId,
            courseTitle: title,
          );
      if (_boundUserId != userId) return;
      final truncated = data.length >= 100;
      final snap = await CourseRollcallsStore.writeSuccess(
        userId: userId,
        courseId: courseId,
        courseTitle: title.isNotEmpty ? title : (previous?.courseTitle ?? ''),
        records: data,
        truncated: truncated,
        at: ref.read(courseHistoryClockProvider)(),
      );
      // Drop legacy prior key if present.
      await JsonDiskCache.remove('course_rollcalls_${userId}_$courseId');
      _courseSnaps[courseId] = snap;
      AppLog.event(
        'history.course.complete',
        fields: {
          'userId': userId,
          'courseId': courseId,
          'count': data.length,
          'durationMs': DateTime.now().difference(started).inMilliseconds,
        },
      );
    } catch (e) {
      if (_boundUserId != userId) return;
      if (wasPending) {
        final pending = ref.read(_seenProvider);
        ref.read(_seenProvider.notifier).state = {...pending, courseId};
      }
      final snap = await CourseRollcallsStore.writeFailure(
        userId: userId,
        courseId: courseId,
        courseTitle: title,
        error: e,
        previous: previous,
      );
      _courseSnaps[courseId] = snap;
      AppLog.event(
        'history.course.failed',
        level: 'W',
        fields: {
          'userId': userId,
          'courseId': courseId,
          'durationMs': DateTime.now().difference(started).inMilliseconds,
          'errorType': e.runtimeType.toString(),
        },
      );
    }
  }

  Future<void> refresh({String? courseId}) =>
      ensureFresh(reason: EnsureFreshReason.pullToRefresh, courseId: courseId);

  Future<void> refreshCourse(String courseId) async {
    await ensureFresh(
      reason: EnsureFreshReason.manualCourse,
      courseId: courseId,
    );
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
    this.missingTimetable = false,
  });

  final SessionPriorSnapshot? snapshot;
  final bool unscoped;
  final int? nowMinutes;
  final bool missingTimetable;
}

/// Course id ? weekday ? slots from sticky catalog (owner session).
final courseTimetablesProvider =
    Provider<Map<String, Map<int, List<TimetableSlot>>>>((ref) {
      final catalog = ref.watch(courseCatalogProvider).valueOrNull;
      return catalog?.timetablesByCourse ?? const {};
    });

/// Session history follows the same credential scope as the active card.
final sessionPriorProvider = FutureProvider.autoDispose
    .family<SessionPriorState, String>(
      (ref, courseId) => _loadSessionPrior(ref, courseId, null),
    );
final scopedSessionPriorProvider = FutureProvider.autoDispose
    .family<SessionPriorState, ({String courseId, int accountId})>(
      (ref, key) => _loadSessionPrior(ref, key.courseId, key.accountId),
    );
Future<SessionPriorState> _loadSessionPrior(
  Ref ref,
  String courseId,
  int? assistUserId,
) async {
  final profile = ref.watch(authControllerProvider).profile;
  if (profile == null || profile.id == 0) {
    return const SessionPriorState(unscoped: true);
  }
  final studentId = assistUserId ?? profile.id;
  final catalogProvider = ref.watch(scopedCourseCatalogProvider(assistUserId));
  final cid = courseId.trim();
  if (cid.isEmpty) return const SessionPriorState(unscoped: true);

  final now = DateTime.now();
  // Ensure catalog loaded (sticky).
  await ref.watch(catalogProvider.future);
  if (ref.read(authControllerProvider).profile?.id != profile.id) {
    return const SessionPriorState(unscoped: true);
  }
  final tables =
      ref.watch(catalogProvider).valueOrNull?.timetablesByCourse ??
      const <String, Map<int, List<TimetableSlot>>>{};
  final byDay = tables[cid];
  if (byDay == null || byDay.isEmpty) {
    return const SessionPriorState(unscoped: true, missingTimetable: true);
  }
  final slots = byDay[now.weekday];
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
    studentId: studentId,
    assistUserId: assistUserId,
    courseTitle: ref.read(catalogProvider).valueOrNull?.titlesById[cid] ?? '',
  );
  if (ref.read(authControllerProvider).profile?.id != profile.id) {
    return const SessionPriorState(unscoped: true);
  }
  final snap = buildSessionPrior(
    block: block,
    weekday: now.weekday,
    history: history,
  );
  return SessionPriorState(snapshot: snap, nowMinutes: minutesOfDay(now));
}

Future<List<CourseRollcallRecord>> _fetchCourseRollcallsCached({
  required Ref ref,
  required String courseId,
  required int studentId,
  String courseTitle = '',
  int? assistUserId,
}) async {
  final principalId = ref.read(authControllerProvider).profile?.id;
  final existing = await CourseRollcallsStore.read(studentId, courseId);
  if (existing != null &&
      existing.isFresh(CachePolicy.enterSwrFreshFor) &&
      existing.fetchState != CourseRollcallsFetchState.neverChecked) {
    return existing.records;
  }
  try {
    final data = await ref
        .read(
          assistUserId == null
              ? rollcallRepositoryProvider
              : rollcallRepositoryForProvider(assistUserId),
        )
        .fetchCourseRollcalls(
          courseId: courseId,
          studentId: studentId,
          courseTitle: courseTitle,
        );
    if (ref.read(authControllerProvider).profile?.id != principalId) {
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
