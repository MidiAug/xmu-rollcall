import 'place_matching.dart';
import 'location_validation_store.dart';
import 'campus_places.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/course_meeting.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

Future<CourseRadarPref?> Function(RollcallItem)
createAutomaticRadarLocationReader({
  required int ownerId,
  required int? assistUserId,
  DateTime Function()? now,
}) {
  final observed = <int, DateTime>{};
  return (item) {
    final at = observed.putIfAbsent(
      item.rollcallId,
      () => radarActivityReferenceTime(item, (now ?? DateTime.now)()),
    );
    return readAutomaticRadarLocation(
      ownerId: ownerId,
      assistUserId: assistUserId,
      courseId: item.courseId,
      at: at,
    );
  };
}

String courseRadarMeetingStorageKey(String courseId, String meetingKey) =>
    'id:$courseId@${Uri.encodeComponent(meetingKey)}';

String courseRadarMeetingPreferencePrefix(int ownerId, int? assistUserId) =>
    '${courseRadarPreferencesKey(ownerId, assistUserId)}_meeting_';

String courseRadarMeetingPreferenceKey(
  int ownerId,
  int? assistUserId,
  CourseRadarPref pref,
) =>
    '${courseRadarMeetingPreferencePrefix(ownerId, assistUserId)}'
    '${Uri.encodeComponent(pref.courseId)}_${Uri.encodeComponent(pref.meetingKey)}_'
    '${pref.userConfigured ? 'configured' : 'success_${pref.updatedAtMicros}'}';

CourseRadarPref? newerMeetingPoint(CourseRadarPref? a, CourseRadarPref? b) {
  if (a == null) return b;
  if (b == null) return a;
  if (a.updatedAtMicros == b.updatedAtMicros) return a.userConfigured ? a : b;
  return a.updatedAtMicros > b.updatedAtMicros ? a : b;
}

Future<void> persistMeetingRadarPoint(
  int ownerId,
  int? assistUserId,
  CourseRadarPref pref,
) async {
  if (pref.courseId.isEmpty || pref.meetingKey.isEmpty) return;
  validateRadarLocation(
    latitude: pref.latitude,
    longitude: pref.longitude,
    accuracy: pref.accuracy,
  );
  final prefs = await SharedPreferences.getInstance();
  if (!await prefs.setString(
    courseRadarMeetingPreferenceKey(ownerId, assistUserId, pref),
    jsonEncode(pref.toJson()),
  )) {
    throw StateError('无法保存本次课地点');
  }
  if (!pref.userConfigured) {
    final base = courseRadarMeetingPreferenceKey(
      ownerId,
      assistUserId,
      pref.forMeeting(pref.meetingKey, stamp: 0),
    );
    final prefix = base.substring(0, base.length - 1);
    final versions = prefs.getKeys().where((k) => k.startsWith(prefix)).toList()
      ..sort(
        (a, b) => (int.tryParse(b.substring(prefix.length)) ?? 0).compareTo(
          int.tryParse(a.substring(prefix.length)) ?? 0,
        ),
      );
    for (final old in versions.skip(8)) {
      await prefs.remove(old);
    }
  }
}

String? courseRadarPreferencesKey(int? ownerId, int? assistUserId) {
  if (ownerId == null || ownerId <= 0) return null;
  return assistUserId == null
      ? 'course_radar_defaults_$ownerId'
      : 'course_radar_defaults_${ownerId}_assist_$assistUserId';
}

/// Read the persisted snapshot in either the UI or the Android worker isolate.
/// Automatic submission never falls back to a course title or another account.
Future<List<SavedLocation>> readScopedSavedLocations(
  SharedPreferences prefs,
  int ownerId,
  int uid,
) async {
  final key = savedLocationsKey(ownerId, uid);
  var raw = prefs.getString(key);
  if (raw == null) {
    final legacyOwner = prefs.getInt('saved_locations_legacy_owner');
    if (legacyOwner != null && legacyOwner != ownerId) return const [];
    if (legacyOwner == null) {
      await prefs.setInt('saved_locations_legacy_owner', ownerId);
    }
    final legacy = prefs.getString(savedRadarLocationsKey);
    final all = legacy == null
        ? <Map>[]
        : (jsonDecode(legacy) as List).whereType<Map>().toList();
    final allowed = <String>{};
    if (uid != ownerId) {
      final configKey = courseRadarPreferencesKey(ownerId, uid);
      for (final config in prefs.getKeys().where(
        (k) => k == configKey || k.startsWith('${configKey}_meeting_'),
      )) {
        final data = jsonDecode(prefs.getString(config) ?? '{}');
        final entries = data is Map && data.containsKey('placeId')
            ? [data]
            : data is Map
            ? data.values
            : const [];
        for (final entry in entries.whereType<Map>()) {
          if (entry['userConfigured'] == true && entry['placeId'] is String) {
            allowed.add(entry['placeId'] as String);
          }
        }
      }
    }
    final migrated = uid == ownerId
        ? all
        : all.where((p) => allowed.contains(p['id'])).toList();
    raw = jsonEncode(migrated);
    if (!await prefs.setString(key, raw)) throw StateError('无法迁移当前账号地点');
  }
  return (jsonDecode(raw) as List)
      .whereType<Map>()
      .map((p) => SavedLocation.fromJson(Map<String, dynamic>.from(p)))
      .toList();
}

Future<CourseRadarPref?> readAutomaticRadarLocation({
  required int ownerId,
  required int? assistUserId,
  required String? courseId,
  String? meetingKey,
  DateTime? at,
}) async {
  final key = courseRadarPreferencesKey(ownerId, assistUserId);
  final id = courseId?.trim() ?? '';
  if (key == null || id.isEmpty) return null;
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final raw = prefs.getString(key);
  try {
    final map = raw == null ? <String, dynamic>{} : jsonDecode(raw) as Map;
    final meeting =
        meetingKey ??
        await resolveRadarMeeting(
          ownerId: ownerId,
          assistUserId: assistUserId,
          courseId: id,
          at: at ?? DateTime.now(),
        );
    CourseRadarPref? scoped;
    if (meeting != null) {
      for (final configured in [true, false]) {
        final probe = CourseRadarPref(
          courseTitle: '',
          courseId: id,
          latitude: 0,
          longitude: 0,
          meetingKey: meeting,
          userConfigured: configured,
        );
        final storedKey = courseRadarMeetingPreferenceKey(
          ownerId,
          assistUserId,
          probe,
        );
        final keys = configured
            ? [storedKey]
            : prefs.getKeys().where(
                (k) =>
                    k.startsWith(storedKey.substring(0, storedKey.length - 1)),
              );
        for (final candidateKey in keys) {
          final saved = prefs.getString(candidateKey);
          if (saved == null) continue;
          final candidate = CourseRadarPref.fromJson(
            Map<String, dynamic>.from(jsonDecode(saved) as Map),
          );
          if (candidate.courseId != id || candidate.meetingKey != meeting) {
            return null;
          }
          scoped = newerMeetingPoint(scoped, candidate);
        }
      }
    }
    final entry = scoped?.toJson() ?? map['id:$id'] ?? map[id];
    if (entry is! Map) return null;
    final pref = CourseRadarPref.fromJson(Map<String, dynamic>.from(entry));
    if (pref.courseId != id) return null;
    if (scoped != null && pref.meetingKey != meeting) return null;
    // Old course-wide successes cannot silently become another meeting's point.
    if (scoped == null && !pref.userConfigured) return null;
    final effective = pref.forMeeting(meeting ?? '');
    if (pref.placeId.isNotEmpty) {
      final saved = await readScopedSavedLocations(
        prefs,
        ownerId,
        assistUserId ?? ownerId,
      );
      final places = [
        ...campusPlaces.map((p) => p.saved.toJson()),
        if (teachingLocationById(pref.placeId) case final place?)
          place.toJson(),
        ...saved.map((p) => p.toJson()),
      ];
      final matches = places.whereType<Map>().where(
        (p) => p['id'] == pref.placeId,
      );
      if (matches.length != 1) return null;
      final place = SavedLocation.fromJson(
        Map<String, dynamic>.from(matches.single),
      );
      validateRadarLocation(
        latitude: place.latitude,
        longitude: place.longitude,
        accuracy: place.accuracy,
      );
      // Automatic use follows the exact current place, never a deleted snapshot
      // or a different nearby/name-matched place. Manual confirmation may retain
      // the old snapshot as a visible suggestion.
      final resolved = CourseRadarPref(
        courseTitle: pref.courseTitle,
        courseId: pref.courseId,
        latitude: place.latitude,
        longitude: place.longitude,
        accuracy: place.accuracy,
        placeId: place.id,
        obtainedVia: RadarObtainedVia.place.storageKey,
        labelSnapshot: place.note,
        userConfigured: pref.userConfigured,
        meetingKey: effective.meetingKey,
        updatedAtMicros: effective.updatedAtMicros,
      );
      return await isRejectedLocation(
            ownerId,
            assistUserId ?? ownerId,
            resolved,
          )
          ? null
          : resolved;
    }
    validateRadarLocation(
      latitude: pref.latitude,
      longitude: pref.longitude,
      accuracy: pref.accuracy,
    );
    return await isRejectedLocation(ownerId, assistUserId ?? ownerId, effective)
        ? null
        : effective;
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  } on ArgumentError {
    return null;
  }
}

/// Update existing authorized bindings for this named place; never create consent.
Future<void> updateRadarPlaceBindings(
  int owner,
  int? assist,
  List<LocationValidationIssue> issues,
  SavedLocation place,
) async {
  if (issues.any(
    (e) =>
        e.point.latitude == place.latitude &&
        e.point.longitude == place.longitude,
  )) {
    throw ArgumentError('请选择与原定位不同的位置');
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final base = courseRadarPreferencesKey(owner, assist);
  final prefix = courseRadarMeetingPreferencePrefix(owner, assist);
  if (base == null) return;
  Map<String, dynamic> patch(Map<String, dynamic> json) {
    final point = CourseRadarPref.fromJson(json);
    final rejected = issues.any((e) => e.matches(point));
    final sameNamedPlace =
        point.placeId.isNotEmpty &&
        point.labelSnapshot.isNotEmpty &&
        coursePlaceIdentity(point.labelSnapshot) ==
            coursePlaceIdentity(place.note);
    if (!rejected && !sameNamedPlace) return json;
    return {
      ...json,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'accuracy': place.accuracy,
      'placeId': place.id,
      'labelSnapshot': place.note,
      'obtainedVia': RadarObtainedVia.place.name,
      'updatedAtMicros': DateTime.now().microsecondsSinceEpoch,
    };
  }

  for (final key
      in prefs
          .getKeys()
          .where((k) => k == base || k.startsWith(prefix))
          .toList()) {
    final raw = prefs.getString(key);
    if (raw == null) continue;
    final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final updated = key == base
        ? {
            for (final e in json.entries)
              e.key: e.value is Map
                  ? patch(Map<String, dynamic>.from(e.value as Map))
                  : e.value,
          }
        : patch(json);
    if (jsonEncode(updated) != raw &&
        !await prefs.setString(key, jsonEncode(updated))) {
      throw StateError('无法更新已绑定地点');
    }
  }
  await clearLocationIssues(owner, assist ?? owner, issues.map((e) => e.key));
}
