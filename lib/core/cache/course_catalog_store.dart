import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

/// One course in the sticky CourseCatalog (R-35 §4).
class CatalogCourse {
  const CatalogCourse({
    required this.id,
    required this.title,
    Map<int, List<TimetableSlot>> timetables = const {},
    this.localMeetings = const [],
    this.instructorNames = const [],
    this.teachingClassName,
    this.location,
    this.roles = const [],
    // Keep the public argument while separating platform data from local meetings.
    // ignore: prefer_initializing_formals
  }) : _timetables = timetables;

  final String id;
  final String title;

  /// Weekday (1–7) → slots.
  final Map<int, List<TimetableSlot>> _timetables;
  final List<CourseMeeting> localMeetings;
  bool get needsSchedule => _timetables.isEmpty && localMeetings.isEmpty;
  bool get hasPlatformSchedule => _timetables.isNotEmpty;
  Map<int, List<TimetableSlot>> get timetables =>
      _timetables.isNotEmpty || localMeetings.isEmpty
      ? _timetables
      : {
          for (final day in localMeetings.map((m) => m.weekday).toSet())
            day: [
              for (final m in localMeetings)
                if (m.weekday == day) m.slot,
            ],
        };

  CatalogCourse withMeetings(List<CourseMeeting> meetings) => CatalogCourse(
    id: id,
    title: title,
    timetables: _timetables,
    localMeetings: meetings,
    instructorNames: instructorNames,
    teachingClassName: teachingClassName,
    location: location,
    roles: roles,
  );

  /// Instructor display names (may be empty).
  final List<String> instructorNames;

  /// Teaching class label, e.g. 信息1班.
  final String? teachingClassName;

  /// Classroom / place when the API provides one.
  final String? location;
  final List<String> roles;

  bool get isInstructor => roles.contains('instructor');
  bool get isTeachingAssistant =>
      roles.any((r) => r == 'instructor_assistant' || r == 'student_assistant');
  bool get isTeaching => isInstructor || isTeachingAssistant;
  String get roleLabel => isInstructor
      ? '教师'
      : isTeachingAssistant
      ? '助教'
      : '学生';

  CatalogCourse withRoles(List<String> value) => CatalogCourse(
    id: id,
    title: title,
    timetables: _timetables,
    localMeetings: localMeetings,
    instructorNames: instructorNames,
    teachingClassName: teachingClassName,
    location: location,
    roles: value,
  );

  String get instructorsLabel => instructorNames.join('、');

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'roles': roles,
    if (instructorNames.isNotEmpty) 'instructorNames': instructorNames,
    if (teachingClassName != null && teachingClassName!.isNotEmpty)
      'teachingClassName': teachingClassName,
    if (location != null && location!.isNotEmpty) 'location': location,
    if (_timetables.isNotEmpty)
      'timetables': {
        for (final e in _timetables.entries)
          '${e.key}': [for (final s in e.value) timetableSlotToJson(s)],
      },
  };

  factory CatalogCourse.fromJson(Map<String, dynamic> j) {
    final raw = j['timetables'];
    Map<int, List<TimetableSlot>> tables = const {};
    if (raw != null) {
      tables = parseTimetables(raw);
    }
    final instructors = <String>[];
    final rawInstructors = j['instructorNames'] ?? j['instructors'];
    if (rawInstructors is List) {
      for (final e in rawInstructors) {
        if (e is String && e.trim().isNotEmpty) {
          instructors.add(e.trim());
        } else if (e is Map) {
          final n = e['name'];
          if (n is String && n.trim().isNotEmpty) instructors.add(n.trim());
        }
      }
    }
    return CatalogCourse(
      id: '${j['id'] ?? ''}',
      title: j['title'] as String? ?? '',
      timetables: tables,
      instructorNames: instructors,
      teachingClassName: _optionalString(j['teachingClassName']),
      location: _optionalString(j['location']),
      roles: parseCourseRoles(j['roles'] ?? j['course_role'] ?? j['role']),
    );
  }
}

List<String> parseCourseRoles(Object? value) {
  if (value is List) return value.expand(parseCourseRoles).toSet().toList();
  if (value is Map) {
    return parseCourseRoles(value['role'] ?? value['name'] ?? value['type']);
  }
  if (value is! String) return const [];
  return value
      .split(RegExp(r'[,\s]+'))
      .map((r) => r.trim().toLowerCase())
      .where(
        (r) => const {
          'student',
          'student_assistant',
          'instructor',
          'instructor_assistant',
        }.contains(r),
      )
      .toSet()
      .toList();
}

String? _optionalString(dynamic v) {
  if (v is! String) return null;
  final s = v.trim();
  return s.isEmpty ? null : s;
}

class CourseCatalogSnapshot {
  const CourseCatalogSnapshot({
    required this.fetchedAt,
    required this.courses,
    this.semesterId,
    this.academicYearId,
    this.rolesResolved = false,
  });

  final DateTime fetchedAt;
  final List<CatalogCourse> courses;
  final String? semesterId;
  final String? academicYearId;
  final bool rolesResolved;

  /// Same course set rendered by the current timetable page.
  List<CatalogCourse> get timetableCourses =>
      courses.where((c) => c.timetables.isNotEmpty).toList(growable: false);

  Map<String, String> get timetableTitlesById => {
    for (final c in timetableCourses)
      if (c.id.isNotEmpty) c.id: c.title,
  };

  /// Enrolled student courses can have attendance without timetable slots.
  Map<String, String> get attendanceTitlesById => {
    for (final c in courses)
      if (c.id.isNotEmpty && !c.isTeaching) c.id: c.title,
  };

  List<CatalogCourse> get teachingCourses =>
      timetableCourses.where((c) => c.isTeaching).toList(growable: false);

  Map<String, String> get titlesById => {
    for (final c in courses)
      if (c.id.isNotEmpty) c.id: c.title,
  };

  Map<String, Map<int, List<TimetableSlot>>> get timetablesByCourse => {
    for (final c in courses)
      if (c.timetables.isNotEmpty) c.id: c.timetables,
  };

  Map<String, dynamic> toJson() => {
    'fetchedAt': fetchedAt.toIso8601String(),
    'courses': [for (final c in courses) c.toJson()],
    'rolesResolved': rolesResolved,
    if (semesterId != null) 'semesterId': semesterId,
    if (academicYearId != null) 'academicYearId': academicYearId,
  };

  factory CourseCatalogSnapshot.fromJson(Map<String, dynamic> j) {
    final raw = j['courses'];
    final courses = <CatalogCourse>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          courses.add(CatalogCourse.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return CourseCatalogSnapshot(
      fetchedAt:
          DateTime.tryParse(j['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      courses: courses,
      semesterId: j['semesterId'] as String?,
      academicYearId: j['academicYearId'] as String?,
      rolesResolved: j['rolesResolved'] == true,
    );
  }
}

abstract final class CourseCatalogStore {
  static String suffix(int userId) => 'course_catalog_$userId';

  static Future<CourseCatalogSnapshot?> read(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(JsonDiskCache.key(suffix(userId)));
    if (raw == null || raw.isEmpty) return null;
    try {
      return CourseCatalogSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(int userId, CourseCatalogSnapshot snap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      JsonDiskCache.key(suffix(userId)),
      jsonEncode(snap.toJson()),
    );
  }
}

Map<String, dynamic> timetableSlotToJson(TimetableSlot s) {
  String hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return {
    'sequence': s.sequence,
    'start_time': hhmm(s.start),
    'end_time': hhmm(s.end),
  };
}
