import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/course_radar_store.dart';

final radarMeetingClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final savedLocationsProvider =
    StateNotifierProvider<SavedLocationsController, List<SavedLocation>>((ref) {
      return SavedLocationsController();
    });

final courseRadarDefaultsProvider =
    StateNotifierProvider<
      CourseRadarDefaultsController,
      Map<String, CourseRadarPref>
    >((ref) {
      final uid = ref.watch(
        authControllerProvider.select((s) => s.profile?.id),
      );
      return CourseRadarDefaultsController(userId: uid);
    });

final assistCourseRadarDefaultsProvider =
    StateNotifierProvider.family<
      CourseRadarDefaultsController,
      Map<String, CourseRadarPref>,
      int
    >((ref, assistId) {
      final owner = ref.watch(
        authControllerProvider.select((s) => s.profile?.id),
      );
      return CourseRadarDefaultsController(
        userId: owner,
        assistUserId: assistId,
      );
    });

StateNotifierProvider<
  CourseRadarDefaultsController,
  Map<String, CourseRadarPref>
>
courseRadarDefaultsForProvider(int? assistUserId) => assistUserId == null
    ? courseRadarDefaultsProvider
    : assistCourseRadarDefaultsProvider(assistUserId);

class SavedLocationsController extends StateNotifier<List<SavedLocation>> {
  SavedLocationsController() : super(const []) {
    ready = _load();
  }

  late final Future<void> ready;
  Future<void> _writes = Future.value();
  static const _key = savedRadarLocationsKey;
  final _uuid = const Uuid();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .whereType<Map>()
          .map((e) => SavedLocation.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}
  }

  Future<void> _persist() {
    final raw = jsonEncode(state.map((e) => e.toJson()).toList());
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_key, raw)) throw StateError('无法保存地点');
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

  Future<SavedLocation> add({
    required String note,
    required double latitude,
    required double longitude,
    double accuracy = 35,
  }) async {
    await ready;
    if (!mounted) throw StateError('地点页面已关闭');
    validateRadarLocation(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );
    final trimmed = note.trim().isEmpty ? '未命名位置' : note.trim();
    final loc = SavedLocation(
      id: _uuid.v4(),
      note: trimmed,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      createdAt: DateTime.now(),
    );
    state = [loc, ...state];
    await _persist();
    AppLog.event(
      'location.preset.add',
      fields: {
        'idSuffix': loc.id.length <= 6
            ? loc.id
            : loc.id.substring(loc.id.length - 6),
        'noteLen': trimmed.length,
        'latitude': double.parse(latitude.toStringAsFixed(5)),
        'longitude': double.parse(longitude.toStringAsFixed(5)),
        'count': state.length,
      },
    );
    return loc;
  }

  Future<void> remove(String id) async {
    await ready;
    if (!mounted) return;
    state = state.where((e) => e.id != id).toList();
    await _persist();
    AppLog.event(
      'location.preset.remove',
      fields: {
        'idSuffix': id.length <= 6 ? id : id.substring(id.length - 6),
        'count': state.length,
      },
    );
  }

  Future<void> rename(String id, String note) async {
    await ready;
    if (!mounted) return;
    final trimmed = note.trim().isEmpty ? '未命名位置' : note.trim();
    state = [
      for (final e in state)
        if (e.id == id)
          SavedLocation(
            id: e.id,
            note: trimmed,
            latitude: e.latitude,
            longitude: e.longitude,
            accuracy: e.accuracy,
            createdAt: e.createdAt,
          )
        else
          e,
    ];
    await _persist();
    AppLog.event(
      'location.preset.rename',
      fields: {
        'idSuffix': id.length <= 6 ? id : id.substring(id.length - 6),
        'noteLen': trimmed.length,
      },
    );
  }

  Future<void> updateCoords(
    String id, {
    required double latitude,
    required double longitude,
  }) async {
    await ready;
    if (!mounted) return;
    validateRadarLocation(latitude: latitude, longitude: longitude);
    state = [
      for (final e in state)
        if (e.id == id)
          SavedLocation(
            id: e.id,
            note: e.note,
            latitude: latitude,
            longitude: longitude,
            accuracy: e.accuracy,
            createdAt: e.createdAt,
          )
        else
          e,
    ];
    await _persist();
    AppLog.event(
      'location.preset.update_coords',
      fields: {
        'idSuffix': id.length <= 6 ? id : id.substring(id.length - 6),
        'latitude': double.parse(latitude.toStringAsFixed(5)),
        'longitude': double.parse(longitude.toStringAsFixed(5)),
      },
    );
  }
}

class CourseRadarDefaultsController
    extends StateNotifier<Map<String, CourseRadarPref>> {
  CourseRadarDefaultsController({this.userId, this.assistUserId})
    : super(const {}) {
    ready = _load();
  }

  late final Future<void> ready;
  Future<void> _writes = Future.value();
  final int? userId;
  final int? assistUserId;

  static const _legacyKey = 'course_radar_defaults';

  String? get _key => courseRadarPreferencesKey(userId, assistUserId);

  Future<void> _load() async {
    final key = _key;
    if (key == null) {
      state = const {};
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    var raw = prefs.getString(key);
    if (assistUserId == null && (raw == null || raw.isEmpty)) {
      final legacy = prefs.getString(_legacyKey);
      if (legacy != null && legacy.isNotEmpty) {
        await prefs.setString(key, legacy);
        await prefs.remove(_legacyKey);
        raw = legacy;
      }
    }
    if (!mounted) return;
    try {
      final map = raw == null || raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      final loaded = <String, CourseRadarPref>{
        for (final e in map.entries)
          if (e.value is Map)
            e.key: CourseRadarPref.fromJson(
              Map<String, dynamic>.from(e.value as Map),
            ),
      };
      for (final entryKey in prefs.getKeys().where(
        (k) => k.startsWith(
          courseRadarMeetingPreferencePrefix(userId!, assistUserId),
        ),
      )) {
        try {
          final point = CourseRadarPref.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(prefs.getString(entryKey)!) as Map,
            ),
          );
          if (point.meetingKey.isEmpty || point.courseId.isEmpty) continue;
          final meetingKey = courseRadarMeetingStorageKey(
            point.courseId,
            point.meetingKey,
          );
          loaded[meetingKey] = newerMeetingPoint(loaded[meetingKey], point)!;
        } catch (_) {
          /* A damaged meeting does not discard the others. */
        }
      }
      if (mounted) state = loaded;
    } catch (_) {
      state = const {};
    }
  }

  Future<void> _persist() {
    final key = _key;
    if (key == null) return Future.value();
    final raw = jsonEncode({
      for (final e in state.entries)
        if (e.value.meetingKey.isEmpty) e.key: e.value.toJson(),
    });
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, raw)) throw StateError('无法保存课程位置');
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

  Future<void> reload() async {
    await ready;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await _load();
  }

  CourseRadarPref? forCourse({
    String? courseId,
    String courseTitle = '',
    String? meetingKey,
  }) {
    final id = courseId?.trim() ?? '';
    if (id.isNotEmpty) {
      if (meetingKey?.isNotEmpty == true) {
        final meeting = state[courseRadarMeetingStorageKey(id, meetingKey!)];
        if (meeting != null) return meeting;
      }
      final byId = state['id:$id'] ?? state[id];
      if (byId != null && (meetingKey == null || byId.userConfigured)) {
        return byId;
      }
    }
    if (meetingKey != null) return null;
    final title = courseTitle.trim();
    if (title.isEmpty) return null;
    final byTitle = state['t:$title'] ?? state[title];
    if (id.isNotEmpty &&
        byTitle != null &&
        byTitle.courseId.isNotEmpty &&
        byTitle.courseId != id) {
      return null;
    }
    return byTitle;
  }

  Future<void> rememberSuccess({
    required String courseTitle,
    String? courseId,
    required double latitude,
    required double longitude,
    double accuracy = 35,
    String placeId = '',
    required RadarObtainedVia obtainedVia,
    String labelSnapshot = '',
    String meetingKey = '',
    int? submittedAtMicros,
  }) async {
    if (meetingKey.isEmpty || (courseId?.trim().isEmpty ?? true)) return;
    await _remember(
      CourseRadarPref(
        courseTitle: courseTitle.trim(),
        courseId: courseId?.trim() ?? '',
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        placeId: placeId,
        obtainedVia: obtainedVia.storageKey,
        labelSnapshot: labelSnapshot,
        meetingKey: meetingKey,
        updatedAtMicros:
            submittedAtMicros ?? DateTime.now().microsecondsSinceEpoch,
      ),
    );
  }

  Future<void> configureForCourse({
    required String courseId,
    required String courseTitle,
    required RadarGeoSelection selection,
    Iterable<String> meetingKeys = const [],
  }) async {
    await ready;
    final point = CourseRadarPref(
      courseTitle: courseTitle.trim(),
      courseId: courseId.trim(),
      latitude: selection.latitude,
      longitude: selection.longitude,
      accuracy: selection.accuracy,
      placeId: selection.placeId,
      obtainedVia: selection.obtainedVia.storageKey,
      labelSnapshot: selection.label,
      userConfigured: true,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
    final targets = meetingKeys.where((k) => k.isNotEmpty).toSet();
    final shared = state['id:${courseId.trim()}'] ?? state[courseId.trim()];
    if (targets.isEmpty || shared?.userConfigured != true) {
      await _remember(point);
    }
    for (final meeting in targets) {
      await _remember(point.forMeeting(meeting));
    }
  }

  Future<void> _remember(CourseRadarPref pref) async {
    await ready;
    if (!mounted || _key == null) return;
    validateRadarLocation(
      latitude: pref.latitude,
      longitude: pref.longitude,
      accuracy: pref.accuracy,
    );
    final title = pref.courseTitle;
    final id = pref.courseId;
    final key = pref.meetingKey.isEmpty
        ? courseRadarStorageKey(courseId: id, courseTitle: title)
        : courseRadarMeetingStorageKey(id, pref.meetingKey);
    if (key.isEmpty) return;

    final next = Map<String, CourseRadarPref>.from(state);
    next[key] = pref.meetingKey.isEmpty
        ? pref
        : newerMeetingPoint(next[key], pref)!;
    // Drop legacy bare-title key once we have a stable id key.
    if (id.isNotEmpty && title.isNotEmpty) {
      next.remove(title);
      next.remove('t:$title');
    }
    state = next;
    if (pref.meetingKey.isEmpty) {
      await _persist();
    } else {
      await persistMeetingRadarPoint(userId!, assistUserId, pref);
    }
    AppLog.event(
      'location.course.remember',
      fields: {
        'courseId': id,
        'scope': assistUserId == null ? 'owner' : 'assist',
        'source': pref.obtainedVia,
        'hasPlace': pref.placeId.isNotEmpty,
        'userConfigured': pref.userConfigured,
      },
    );
  }
}
