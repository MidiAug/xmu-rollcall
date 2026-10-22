import 'dart:math' as math;

/// Durable named point (classroom / virtual location).
class SavedLocation {
  const SavedLocation({
    required this.id,
    required this.note,
    required this.latitude,
    required this.longitude,
    this.accuracy = 35,
    required this.createdAt,
  });

  final String id;
  final String note;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'note': note,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavedLocation.fromJson(Map<String, dynamic> j) {
    return SavedLocation(
      id: j['id'] as String? ?? '',
      note: j['note'] as String? ?? '',
      latitude: (j['latitude'] as num).toDouble(),
      longitude: (j['longitude'] as num).toDouble(),
      accuracy: (j['accuracy'] as num?)?.toDouble() ?? 35,
      createdAt:
          DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// How the current selection's coordinates were obtained.
enum RadarObtainedVia {
  device,
  map,
  place;

  String get storageKey => name;

  static RadarObtainedVia? tryParse(String raw) {
    final v = raw.trim();
    if (v == 'preset') return RadarObtainedVia.place;
    for (final e in values) {
      if (e.name == v) return e;
    }
    return null;
  }
}

/// Why the confirmation card was pre-filled (not a source badge).
enum RadarFilledFrom { none, pref, user }

/// Per-course last-success preference (suggestion, not a fourth "source").
class CourseRadarPref {
  const CourseRadarPref({
    required this.courseTitle,
    this.courseId = '',
    required this.latitude,
    required this.longitude,
    this.accuracy = 35,
    this.placeId = '',
    this.obtainedVia = '',
    this.labelSnapshot = '',
  });

  final String courseTitle;
  final String courseId;
  final double latitude;
  final double longitude;
  final double accuracy;

  /// When set, resolve display via [SavedLocation]; coords are a fallback snapshot.
  final String placeId;

  /// [RadarObtainedVia.storageKey]; empty on legacy rows.
  final String obtainedVia;

  /// Last known place label (if place was deleted) or empty.
  final String labelSnapshot;

  Map<String, dynamic> toJson() => {
    'courseTitle': courseTitle,
    'courseId': courseId,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'placeId': placeId,
    'obtainedVia': obtainedVia,
    'labelSnapshot': labelSnapshot,
    // Legacy keys still written so older builds can read something useful.
    'note': labelSnapshot,
    'source': obtainedVia == 'place' ? 'preset' : obtainedVia,
  };

  factory CourseRadarPref.fromJson(Map<String, dynamic> j) {
    final obtained = (j['obtainedVia'] as String?)?.trim() ?? '';
    final legacySource = (j['source'] as String?)?.trim() ?? '';
    final note = (j['note'] as String?)?.trim() ?? '';
    final label = (j['labelSnapshot'] as String?)?.trim() ?? '';
    return CourseRadarPref(
      courseTitle: j['courseTitle'] as String? ?? '',
      courseId: j['courseId'] as String? ?? '',
      latitude: (j['latitude'] as num).toDouble(),
      longitude: (j['longitude'] as num).toDouble(),
      accuracy: (j['accuracy'] as num?)?.toDouble() ?? 35,
      placeId: j['placeId'] as String? ?? '',
      obtainedVia: obtained.isNotEmpty ? obtained : legacySource,
      labelSnapshot: label.isNotEmpty ? label : unwrapRememberedNote(note),
    );
  }
}

/// @Deprecated — use [CourseRadarPref].
typedef CourseRadarDefault = CourseRadarPref;

/// In-session selection before radar submit.
class RadarGeoSelection {
  const RadarGeoSelection({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.obtainedVia,
    this.placeId = '',
    this.label = '',
    this.filledFrom = RadarFilledFrom.none,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final RadarObtainedVia obtainedVia;
  final String placeId;
  final String label;
  final RadarFilledFrom filledFrom;

  String get confirmLine {
    final copy = radarPlaceCopy(this);
    return '${copy.badge}  ${copy.title}';
  }

  RadarGeoSelection copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    RadarObtainedVia? obtainedVia,
    String? placeId,
    String? label,
    RadarFilledFrom? filledFrom,
  }) {
    return RadarGeoSelection(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      obtainedVia: obtainedVia ?? this.obtainedVia,
      placeId: placeId ?? this.placeId,
      label: label ?? this.label,
      filledFrom: filledFrom ?? this.filledFrom,
    );
  }
}

/// Badge + primary (+ optional pref hint) on the confirmation card.
class RadarPlaceCopy {
  const RadarPlaceCopy({
    required this.badge,
    required this.title,
    this.subtitle,
  });

  final String badge;
  final String title;
  final String? subtitle;
}

/// Classroom-scale match for legacy rows without [CourseRadarPref.placeId].
const double kPresetMatchMeters = 80;

String courseRadarStorageKey({String? courseId, String courseTitle = ''}) {
  final id = courseId?.trim() ?? '';
  if (id.isNotEmpty) return 'id:$id';
  final title = courseTitle.trim();
  if (title.isEmpty) return '';
  return 't:$title';
}

RadarPlaceCopy radarPlaceCopy(RadarGeoSelection selection) {
  final label = selection.label.trim();
  final title = label.isNotEmpty
      ? label
      : switch (selection.obtainedVia) {
          RadarObtainedVia.device => '当前位置',
          RadarObtainedVia.map => '地图所选位置',
          RadarObtainedVia.place => '已保存的地点',
        };
  return RadarPlaceCopy(
    badge: _viaBadge(selection.obtainedVia),
    title: title,
    subtitle: selection.filledFrom == RadarFilledFrom.pref ? '本课上次成功用过' : null,
  );
}

String _viaBadge(RadarObtainedVia via) => switch (via) {
  RadarObtainedVia.device => '系统定位',
  RadarObtainedVia.map => '地图选点',
  RadarObtainedVia.place => '预设',
};

SavedLocation? placeById(List<SavedLocation> places, String placeId) {
  final id = placeId.trim();
  if (id.isEmpty) return null;
  for (final p in places) {
    if (p.id == id) return p;
  }
  return null;
}

SavedLocation? nearestSavedLocation(
  List<SavedLocation> places, {
  required double latitude,
  required double longitude,
}) {
  SavedLocation? best;
  var bestMeters = kPresetMatchMeters;
  for (final place in places) {
    final meters = metersBetween(
      latitude,
      longitude,
      place.latitude,
      place.longitude,
    );
    if (meters <= bestMeters) {
      best = place;
      bestMeters = meters;
    }
  }
  return best;
}

RadarGeoSelection selectionFromCoursePref(
  CourseRadarPref pref,
  List<SavedLocation> places,
) {
  final byId = placeById(places, pref.placeId);
  if (byId != null) {
    return RadarGeoSelection(
      latitude: byId.latitude,
      longitude: byId.longitude,
      accuracy: byId.accuracy,
      obtainedVia: RadarObtainedVia.place,
      placeId: byId.id,
      label: byId.note,
      filledFrom: RadarFilledFrom.pref,
    );
  }

  final via = _resolveVia(pref, places);
  if (via == RadarObtainedVia.place) {
    final matched = nearestSavedLocation(
      places,
      latitude: pref.latitude,
      longitude: pref.longitude,
    );
    final label = matched?.note.trim().isNotEmpty == true
        ? matched!.note
        : (_isGenericSourceNote(pref.labelSnapshot)
              ? ''
              : pref.labelSnapshot.trim());
    return RadarGeoSelection(
      latitude: matched?.latitude ?? pref.latitude,
      longitude: matched?.longitude ?? pref.longitude,
      accuracy: matched?.accuracy ?? pref.accuracy,
      obtainedVia: RadarObtainedVia.place,
      placeId: matched?.id ?? '',
      label: label,
      filledFrom: RadarFilledFrom.pref,
    );
  }

  return RadarGeoSelection(
    latitude: pref.latitude,
    longitude: pref.longitude,
    accuracy: pref.accuracy,
    obtainedVia: via,
    label: _isGenericSourceNote(pref.labelSnapshot)
        ? ''
        : pref.labelSnapshot.trim(),
    filledFrom: RadarFilledFrom.pref,
  );
}

/// @Deprecated — use [selectionFromCoursePref].
RadarGeoSelection selectionFromCourseDefault(
  CourseRadarPref pref,
  List<SavedLocation> places,
) => selectionFromCoursePref(pref, places);

RadarObtainedVia _resolveVia(CourseRadarPref pref, List<SavedLocation> places) {
  final parsed = RadarObtainedVia.tryParse(pref.obtainedVia);
  if (parsed != null) return parsed;
  if (pref.placeId.trim().isNotEmpty) return RadarObtainedVia.place;
  final snap = pref.labelSnapshot.trim();
  if (snap == '系统定位') return RadarObtainedVia.device;
  if (snap == '地图' || snap == '地图选点') return RadarObtainedVia.map;
  if (!_isGenericSourceNote(snap)) return RadarObtainedVia.place;
  final matched = nearestSavedLocation(
    places,
    latitude: pref.latitude,
    longitude: pref.longitude,
  );
  if (matched != null) return RadarObtainedVia.place;
  return RadarObtainedVia.device;
}

String unwrapRememberedNote(String note) {
  final n = note.trim();
  const prefix = '本课上次成功点（';
  if (n == '本课上次成功点') return '';
  if (n.startsWith(prefix) && (n.endsWith('）') || n.endsWith(')'))) {
    return n.substring(prefix.length, n.length - 1).trim();
  }
  return n;
}

bool _isGenericSourceNote(String note) {
  return note.isEmpty ||
      note == '系统定位' ||
      note == '地图' ||
      note == '地图选点' ||
      note == '当前位置' ||
      note == '地图所选位置' ||
      note == '本课上次位置' ||
      note == '本课上次成功点' ||
      note == '已保存的地点';
}

double metersBetween(double lat1, double lon1, double lat2, double lon2) {
  const earth = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earth * math.asin(math.sqrt(a.toDouble()));
}
