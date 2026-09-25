import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
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
      return CourseRadarDefaultsController();
    });

class SavedLocationsController extends StateNotifier<List<SavedLocation>> {
  SavedLocationsController() : super(const []) {
    _load();
  }

  static const _key = 'saved_radar_locations';
  final _uuid = const Uuid();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
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

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  Future<SavedLocation> add({
    required String note,
    required double latitude,
    required double longitude,
    double accuracy = 35,
  }) async {
    final trimmed = note.trim().isEmpty ? '未命名位置' : note.trim();
    final loc = SavedLocation(
      id: _uuid.v4(),
      note: trimmed,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy.clamp(5, 100),
      createdAt: DateTime.now(),
    );
    state = [loc, ...state];
    await _persist();
    AppLog.event(
      'location.preset.add',
      fields: {
        'idSuffix': loc.id.length <= 6 ? loc.id : loc.id.substring(loc.id.length - 6),
        'noteLen': trimmed.length,
        'latitude': double.parse(latitude.toStringAsFixed(5)),
        'longitude': double.parse(longitude.toStringAsFixed(5)),
        'count': state.length,
      },
    );
    return loc;
  }

  Future<void> remove(String id) async {
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
  CourseRadarDefaultsController() : super(const {}) {
    _load();
  }

  static const _key = 'course_radar_defaults';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      state = {
        for (final e in map.entries)
          if (e.value is Map)
            e.key: CourseRadarPref.fromJson(
              Map<String, dynamic>.from(e.value as Map),
            ),
      };
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}),
    );
  }

  CourseRadarPref? forCourse({String? courseId, String courseTitle = ''}) {
    final id = courseId?.trim() ?? '';
    if (id.isNotEmpty) {
      final byId = state['id:$id'] ?? state[id];
      if (byId != null) return byId;
    }
    final title = courseTitle.trim();
    if (title.isEmpty) return null;
    return state['t:$title'] ?? state[title];
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
    final title = courseTitle.trim();
    final id = courseId?.trim() ?? '';
    final key = courseRadarStorageKey(courseId: id, courseTitle: title);
    if (key.isEmpty) return;

    final pref = CourseRadarPref(
      courseTitle: title.isEmpty ? key : title,
      courseId: id,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy.clamp(5, 100),
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
  }
}
