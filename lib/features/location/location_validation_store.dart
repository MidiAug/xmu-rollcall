import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'course_meeting.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_models.dart';
import 'place_matching.dart';

class LocationValidationIssue {
  const LocationValidationIssue(this.point, this.at);
  final CourseRadarPref point;
  final DateTime at;
  String get key => jsonEncode([
    point.courseId,
    point.meetingKey,
    point.placeId,
    point.latitude,
    point.longitude,
  ]);
  bool matches(CourseRadarPref other) =>
      point.latitude == other.latitude &&
      point.longitude == other.longitude &&
      ((point.placeId.isNotEmpty && point.placeId == other.placeId) ||
          (point.labelSnapshot.isNotEmpty &&
              other.labelSnapshot.isNotEmpty &&
              coursePlaceIdentity(point.labelSnapshot) ==
                  coursePlaceIdentity(other.labelSnapshot)) ||
          (point.courseId == other.courseId &&
              (point.meetingKey == other.meetingKey ||
                  other.meetingKey.isEmpty)));
  bool concerns(String name, List<String> courses) =>
      coursePlaceIdentity(
        point.labelSnapshot.isEmpty
            ? '${point.courseTitle}上课地点'
            : point.labelSnapshot,
      ) ==
      coursePlaceIdentity(name);
  Map<String, dynamic> toJson() => {
    'point': point.toJson(),
    'at': at.toIso8601String(),
  };
}

String _key(int owner, int user) => 'radar_location_validation_${owner}_$user';
Future<List<LocationValidationIssue>> readLocationIssues(
  int owner,
  int user,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  try {
    final raw = prefs.getString(_key(owner, user));
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .whereType<Map>()
        .map(
          (e) => LocationValidationIssue(
            CourseRadarPref.fromJson(
              Map<String, dynamic>.from(e['point'] as Map),
            ),
            DateTime.parse(e['at'] as String),
          ),
        )
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> recordLocationIssue(
  int owner,
  int user,
  CourseRadarPref point,
) async {
  final issues = await readLocationIssues(owner, user);
  // Attribute a rejected manual point to the exact cached meeting when known.
  // Ambiguous multi-area meetings remain their own correction entry.
  final catalog = await CourseCatalogStore.read(user);
  final course = catalog?.courses
      .where((c) => c.id == point.courseId)
      .firstOrNull;
  if (course != null) {
    final complete = course.withMeetings(
      await CourseScheduleStore.read(user, point.courseId),
    );
    final rooms = <String>[
      for (final day in complete.timetables.entries)
        for (final block in courseMeetingBlocks(day.value))
          if (courseMeetingKey(day.key, block) == point.meetingKey)
            for (final slot in day.value)
              if (slot.sequence <= block.endSequence &&
                  slot.lastSequence >= block.startSequence &&
                  slot.classroom?.trim().isNotEmpty == true)
                slot.classroom!,
    ];
    if (rooms.isEmpty && course.location?.trim().isNotEmpty == true) {
      rooms.add(course.location!);
    }
    final names = {
      for (final name in rooms.expand(coursePlaceNames))
        coursePlaceIdentity(name): name,
    };
    if (names.length == 1) {
      point = CourseRadarPref.fromJson({
        ...point.toJson(),
        'labelSnapshot': names.values.single,
      });
    }
  }
  final next = LocationValidationIssue(point, DateTime.now());
  final prefs = await SharedPreferences.getInstance();
  final all = [next, ...issues.where((e) => e.key != next.key)].take(200);
  if (!await prefs.setString(
    _key(owner, user),
    jsonEncode(all.map((e) => e.toJson()).toList()),
  )) {
    throw StateError('无法保存地点校验状态');
  }
}

Future<void> clearLocationIssues(
  int owner,
  int user,
  Iterable<String> keys,
) async {
  final remove = keys.toSet();
  if (remove.isEmpty) return;
  final issues = await readLocationIssues(owner, user);
  final prefs = await SharedPreferences.getInstance();
  if (!await prefs.setString(
    _key(owner, user),
    jsonEncode(
      issues
          .where((e) => !remove.contains(e.key))
          .map((e) => e.toJson())
          .toList(),
    ),
  )) {
    throw StateError('无法更新地点校验状态');
  }
}

Future<bool> isRejectedLocation(
  int owner,
  int user,
  CourseRadarPref point,
) async => (await readLocationIssues(owner, user)).any((e) => e.matches(point));
