import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';

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
  static const _key = 'saved_radar_locations';
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

  String? get _key {
    final id = userId;
    if (id == null || id == 0) return null;
    return assistUserId == null
        ? 'course_radar_defaults_$id'
        : 'course_radar_defaults_${id}_assist_$assistUserId';
  }

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
    if (raw == null || raw.isEmpty) {
      state = const {};
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      state = {
        for (final e in map.entries)
          if (e.value is Map)
            e.key: CourseRadarPref.fromJson(
              Map<String, dynamic>.from(e.value as Map),
            ),
      };
    } catch (_) {
      state = const {};
    }
  }

  Future<void> _persist() {
    final key = _key;
    if (key == null) return Future.value();
    final raw = jsonEncode({
      for (final e in state.entries) e.key: e.value.toJson(),
    });
    final write = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, raw)) throw StateError('无法保存课程位置');
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

  CourseRadarPref? forCourse({String? courseId, String courseTitle = ''}) {
    final id = courseId?.trim() ?? '';
    if (id.isNotEmpty) {
      final byId = state['id:$id'] ?? state[id];
      if (byId != null) return byId;
    }
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
  }) async {
    await ready;
    if (!mounted) return;
    validateRadarLocation(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );
    final title = courseTitle.trim();
    final id = courseId?.trim() ?? '';
    final key = courseRadarStorageKey(courseId: id, courseTitle: title);
    if (key.isEmpty) return;

    final pref = CourseRadarPref(
      courseTitle: title.isEmpty ? key : title,
      courseId: id,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      placeId: placeId,
      obtainedVia: obtainedVia.storageKey,
      labelSnapshot: labelSnapshot,
    );

    final next = Map<String, CourseRadarPref>.from(state);
    next[key] = pref;
    // Drop legacy bare-title key once we have a stable id key.
    if (id.isNotEmpty && title.isNotEmpty) {
      next.remove(title);
      next.remove('t:$title');
    }
    state = next;
    await _persist();
    AppLog.event(
      'location.course.remember',
      fields: {
        'courseId': id,
        'scope': assistUserId == null ? 'owner' : 'assist',
        'source': obtainedVia.storageKey,
        'hasPlace': placeId.isNotEmpty,
      },
    );
  }
}
