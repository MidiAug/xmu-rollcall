import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';

final savedLocationsProvider =
    StateNotifierProvider<SavedLocationsController, List<SavedLocation>>((ref) {
  return SavedLocationsController();
});

final courseRadarDefaultsProvider =
    StateNotifierProvider<CourseRadarDefaultsController,
        Map<String, CourseRadarDefault>>((ref) {
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
    return loc;
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _persist();
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
  }
}

class CourseRadarDefaultsController
    extends StateNotifier<Map<String, CourseRadarDefault>> {
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
            e.key: CourseRadarDefault.fromJson(
              Map<String, dynamic>.from(e.value as Map),
            ),
      };
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        for (final e in state.entries) e.key: e.value.toJson(),
      }),
    );
  }

  CourseRadarDefault? forCourse(String courseTitle) {
    final key = courseTitle.trim();
    if (key.isEmpty) return null;
    return state[key];
  }

  Future<void> rememberSuccess({
    required String courseTitle,
    required double latitude,
    required double longitude,
    double accuracy = 35,
    String note = '',
  }) async {
    final key = courseTitle.trim();
    if (key.isEmpty) return;
    final next = Map<String, CourseRadarDefault>.from(state);
    next[key] = CourseRadarDefault(
      courseTitle: key,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy.clamp(5, 100),
      note: note,
    );
    state = next;
    await _persist();
  }
}
