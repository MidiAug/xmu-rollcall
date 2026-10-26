import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

/// One user-entered meeting, including its own classroom and period range.
class CourseMeeting {
  const CourseMeeting({
    required this.weekday,
    required this.first,
    required this.last,
    required this.startMinutes,
    required this.endMinutes,
    this.classroom = '',
  });
  final int weekday;
  final int first;
  final int last;
  final int startMinutes;
  final int endMinutes;
  final String classroom;

  bool get valid =>
      weekday >= 1 &&
      weekday <= 7 &&
      first >= 1 &&
      last >= first &&
      last <= 20 &&
      startMinutes >= 0 &&
      endMinutes < 1440 &&
      endMinutes > startMinutes;

  TimetableSlot get slot => TimetableSlot(
    sequence: first,
    endSequence: last,
    start: DateTime(2000, 1, 3, startMinutes ~/ 60, startMinutes % 60),
    end: DateTime(2000, 1, 3, endMinutes ~/ 60, endMinutes % 60),
    classroom: classroom,
  );

  Map<String, dynamic> toJson() => {
    'weekday': weekday,
    'first': first,
    'last': last,
    'start': startMinutes,
    'end': endMinutes,
    'classroom': classroom,
  };
  factory CourseMeeting.fromJson(Map<String, dynamic> j) => CourseMeeting(
    weekday: j['weekday'] as int,
    first: j['first'] as int,
    last: j['last'] as int,
    startMinutes: j['start'] as int,
    endMinutes: j['end'] as int,
    classroom: j['classroom'] as String? ?? '',
  );
}

/// User data, separate from remote caches so cache clearing keeps the schedule.
abstract final class CourseScheduleStore {
  static String key(int userId, String courseId) =>
      'course_schedule_v1_${userId}_$courseId';

  static Future<List<CourseMeeting>> read(int userId, String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key(userId, courseId));
    if (raw == null) return const [];
    try {
      final values = jsonDecode(raw) as List;
      return values
          .map(
            (v) => CourseMeeting.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .where((m) => m.valid)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> write(
    int userId,
    String courseId,
    List<CourseMeeting> meetings,
  ) async {
    if (meetings.any((m) => !m.valid)) throw const FormatException('上课安排无效');
    for (var i = 0; i < meetings.length; i++) {
      for (var j = i + 1; j < meetings.length; j++) {
        final a = meetings[i];
        final b = meetings[j];
        if (a.weekday == b.weekday &&
            ((a.first <= b.last && b.first <= a.last) ||
                (a.startMinutes < b.endMinutes &&
                    b.startMinutes < a.endMinutes))) {
          throw const FormatException('同一天的上课安排不能重叠');
        }
      }
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      key(userId, courseId),
      jsonEncode(meetings.map((m) => m.toJson()).toList()),
    )) {
      throw StateError('安排保存失败，请重试');
    }
  }
}
