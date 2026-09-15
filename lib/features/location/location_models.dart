/// A user-saved virtual / classroom point (note + coordinates).
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

/// Last successful radar coordinates for a course (keyed by course title).
class CourseRadarDefault {
  const CourseRadarDefault({
    required this.courseTitle,
    required this.latitude,
    required this.longitude,
    this.accuracy = 35,
    this.note = '',
  });

  final String courseTitle;
  final double latitude;
  final double longitude;
  final double accuracy;
  final String note;

  Map<String, dynamic> toJson() => {
        'courseTitle': courseTitle,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'note': note,
      };

  factory CourseRadarDefault.fromJson(Map<String, dynamic> j) {
    return CourseRadarDefault(
      courseTitle: j['courseTitle'] as String? ?? '',
      latitude: (j['latitude'] as num).toDouble(),
      longitude: (j['longitude'] as num).toDouble(),
      accuracy: (j['accuracy'] as num?)?.toDouble() ?? 35,
      note: j['note'] as String? ?? '',
    );
  }
}

/// In-session selection before radar submit.
class RadarGeoSelection {
  const RadarGeoSelection({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.sourceLabel,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final String sourceLabel;
}
