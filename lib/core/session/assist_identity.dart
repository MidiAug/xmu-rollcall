import 'package:xmu_rollcall/core/session/session_credential.dart';

/// One course shared between owner and an assist identity (cached at import).
class AssistSharedCourse {
  const AssistSharedCourse({required this.id, this.title = ''});

  final String id;
  final String title;

  Map<String, dynamic> toJson() => {
        'id': id,
        if (title.isNotEmpty) 'title': title,
      };

  factory AssistSharedCourse.fromJson(Map<String, dynamic> json) {
    return AssistSharedCourse(
      id: '${json['id'] ?? ''}'.trim(),
      title: (json['title'] as String?)?.trim() ?? '',
    );
  }
}

/// Status for assist-roster shared-course chip (no red badge).
enum AssistSharedCourseStatus {
  /// [AssistIdentity.sharedCoursesSyncedAt] is null.
  neverSynced,

  /// Synced; intersection empty.
  none,

  /// Synced; at least one shared course.
  some,
}

/// Metadata for an imported assist identity (cookies live in SessionKey jar).
class AssistIdentity {
  const AssistIdentity({
    required this.userId,
    required this.displayName,
    required this.kind,
    this.deviceId,
    this.importedAt,
    this.sharedCourses = const [],
    this.sharedCoursesSyncedAt,
  });

  final int userId;
  final String displayName;
  final AssistCredentialKind kind;
  final String? deviceId;
  final DateTime? importedAt;

  /// Owner ∩ assist course ids (and titles) written at import / refresh.
  final List<AssistSharedCourse> sharedCourses;
  final DateTime? sharedCoursesSyncedAt;

  bool sharesCourse(String? courseId) {
    if (courseId == null || courseId.isEmpty) return false;
    return sharedCourses.any((c) => c.id == courseId);
  }

  /// Roster chip: never synced / zero overlap / has overlap.
  AssistSharedCourseStatus get sharedCourseStatus {
    if (sharedCoursesSyncedAt == null) {
      return AssistSharedCourseStatus.neverSynced;
    }
    if (sharedCourses.isEmpty) return AssistSharedCourseStatus.none;
    return AssistSharedCourseStatus.some;
  }

  AssistIdentity copyWith({
    String? displayName,
    AssistCredentialKind? kind,
    String? deviceId,
    DateTime? importedAt,
    List<AssistSharedCourse>? sharedCourses,
    DateTime? sharedCoursesSyncedAt,
    bool clearSharedCoursesSyncedAt = false,
  }) {
    return AssistIdentity(
      userId: userId,
      displayName: displayName ?? this.displayName,
      kind: kind ?? this.kind,
      deviceId: deviceId ?? this.deviceId,
      importedAt: importedAt ?? this.importedAt,
      sharedCourses: sharedCourses ?? this.sharedCourses,
      sharedCoursesSyncedAt: clearSharedCoursesSyncedAt
          ? null
          : (sharedCoursesSyncedAt ?? this.sharedCoursesSyncedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'kind': kind.wire,
        if (deviceId != null && deviceId!.isNotEmpty) 'deviceId': deviceId,
        if (importedAt != null)
          'importedAt': importedAt!.toUtc().toIso8601String(),
        if (sharedCourses.isNotEmpty)
          'sharedCourses': sharedCourses.map((e) => e.toJson()).toList(),
        if (sharedCoursesSyncedAt != null)
          'sharedCoursesSyncedAt':
              sharedCoursesSyncedAt!.toUtc().toIso8601String(),
      };

  factory AssistIdentity.fromJson(Map<String, dynamic> json) {
    final rawShared = json['sharedCourses'];
    final shared = <AssistSharedCourse>[];
    if (rawShared is List) {
      for (final e in rawShared) {
        if (e is! Map) continue;
        final c = AssistSharedCourse.fromJson(Map<String, dynamic>.from(e));
        if (c.id.isNotEmpty) shared.add(c);
      }
    }
    return AssistIdentity(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      displayName: (json['displayName'] as String?) ?? '用户',
      kind: AssistCredentialKindX.parse(json['kind'] as String?),
      deviceId: json['deviceId'] as String?,
      importedAt:
          DateTime.tryParse(json['importedAt'] as String? ?? '')?.toUtc(),
      sharedCourses: shared,
      sharedCoursesSyncedAt: DateTime.tryParse(
        json['sharedCoursesSyncedAt'] as String? ?? '',
      )?.toUtc(),
    );
  }
}
