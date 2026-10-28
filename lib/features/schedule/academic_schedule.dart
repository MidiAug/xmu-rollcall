import 'package:xmu_rollcall/features/schedule/academic_meetings.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

int academicInt(Object? value) => int.tryParse('$value') ?? 0;
String academicText(Object? value) => value?.toString().trim() ?? '';

/// EMAP sends numeric HHmm; some deployments return HH:mm strings.
int academicMinute(Object? value) {
  final raw = academicText(value);
  final parts = raw.contains(':')
      ? raw.split(':')
      : RegExp(r'^\d{3,4}$').hasMatch(raw)
      ? [raw.substring(0, raw.length - 2), raw.substring(raw.length - 2)]
      : <String>[];
  if (parts.length < 2) throw const FormatException('教务节次时间异常');
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    throw const FormatException('教务节次时间异常');
  }
  return h * 60 + m;
}

Set<int> academicWeeks(Object? value) {
  final mask = academicText(value);
  if (!RegExp(r'^[01]{1,60}$').hasMatch(mask)) {
    throw const FormatException('教务周次格式异常');
  }
  return {
    for (var i = 0; i < mask.length; i++)
      if (mask[i] == '1') i + 1,
  };
}

class AcademicSchedule {
  const AcademicSchedule({
    required this.term,
    required this.monday,
    required this.fetchedAt,
    required this.rows,
    this.anchorFromUser = false,
  });
  final String term;
  final DateTime monday;
  final DateTime fetchedAt;
  final bool anchorFromUser;

  /// Only course metadata; identity and credentials are never cached here.
  final List<Map<String, dynamic>> rows;

  static const fields = {
    'KCDM',
    'KCMC',
    'BJDM',
    'BJMC',
    'JSXM',
    'JASMC',
    'ZCBH',
    'XQ',
    'KSJCDM',
    'JSJCDM',
    'KSSJ',
    'JSSJ',
  };

  factory AcademicSchedule.parse({
    required String term,
    required DateTime monday,
    required DateTime at,
    required Map<String, dynamic> payload,
    required Map<int, ({int start, int end})> clock,
    bool anchorFromUser = false,
  }) {
    if (payload['success'] != true || payload['pkjgList'] is! List) {
      throw const FormatException('教务未返回完整课表');
    }
    final rows = <Map<String, dynamic>>[
      for (final raw in payload['pkjgList'] as List)
        {for (final key in fields) key: (raw as Map)[key]},
    ];
    // pkjgList is the current authoritative timetable. Historical ttbList
    // entries may already be reflected there; never apply them a second time.
    for (final r in rows) {
      final start = clock[academicInt(r['KSJCDM'])];
      final end = clock[academicInt(r['JSJCDM'])];
      // Clock is authoritative and is indexed by DM, not list position (lunch exists).
      if (start == null ||
          end == null ||
          start.start >= end.end ||
          academicInt(r['XQ']) < 1 ||
          academicInt(r['XQ']) > 7 ||
          academicText(r['KCDM']).isEmpty) {
        throw const FormatException('教务课次时间不完整');
      }
      r['startMinute'] = start.start;
      r['endMinute'] = end.end;
      academicWeeks(r['ZCBH']);
    }
    return AcademicSchedule(
      term: term,
      monday: monday,
      fetchedAt: at,
      rows: rows,
      anchorFromUser: anchorFromUser,
    );
  }

  Map<String, List<Map<String, dynamic>>> get groups {
    final result = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      result.putIfAbsent('${r['KCDM']}/${r['BJDM']}', () => []).add(r);
    }
    return result;
  }

  Map<int, List<TimetableSlot>> tables(List<Map<String, dynamic>> entries) {
    final groups = <String, List<TimetableSlot>>{};
    final weekdays = <String, int>{};
    for (final r in entries) {
      final weeks = academicWeeks(r['ZCBH']);
      if (weeks.isEmpty) continue;
      final day = academicInt(r['XQ']);
      final key = '${r['KCDM']}/${r['BJDM']}/$day';
      weekdays[key] = day;
      groups
          .putIfAbsent(key, () => [])
          .add(
            TimetableSlot(
              sequence: academicInt(r['KSJCDM']),
              endSequence: academicInt(r['JSJCDM']),
              start: DateTime(2000, 1, 3, 0, academicInt(r['startMinute'])),
              end: DateTime(2000, 1, 3, 0, academicInt(r['endMinute'])),
              classroom: academicText(r['JASMC']),
              dates: {
                for (final w in weeks)
                  TimetableSlot.dateKey(
                    monday.add(Duration(days: (w - 1) * 7 + day - 1)),
                  ),
              },
            ),
          );
    }
    final result = <int, List<TimetableSlot>>{};
    for (final entry in groups.entries) {
      result
          .putIfAbsent(weekdays[entry.key]!, () => [])
          .addAll(normalizeAcademicSlots(entry.value, monday));
    }
    return result;
  }

  /// Union of every academic course, including courses absent from TronClass.
  Map<int, List<TimetableSlot>> get allTables => tables(rows);

  List<CatalogCourse> apply(
    List<CatalogCourse> courses, {
    Map<String, String> bindings = const {},
  }) {
    String name(Object? v) => academicText(v)
        .toLowerCase()
        .replaceAll(RegExp(r'[（(][^）)]*[）)]'), '')
        .replaceAll(RegExp(r'[\s·•]'), '');
    final grouped = groups;
    final validCourseIds = courses
        .where((c) => !c.isTeaching)
        .map((c) => c.id)
        .toSet();
    final proposals = <String, List<String>>{};
    for (final course in courses.where((c) => !c.isTeaching)) {
      var candidates = grouped.entries
          .where(
            (e) =>
                academicText(course.courseCode).isNotEmpty &&
                academicText(e.value.first['KCDM']) == course.courseCode,
          )
          .map((e) => e.key)
          .toList();
      if (candidates.isEmpty) {
        candidates = grouped.entries
            .where((e) => name(e.value.first['KCMC']) == name(course.title))
            .map((e) => e.key)
            .toList();
      }
      if (candidates.length > 1) {
        candidates = candidates.where((key) {
          final row = grouped[key]!.first;
          return (course.teachingClassName?.isNotEmpty == true &&
                  name(row['BJMC']) == name(course.teachingClassName)) ||
              course.instructorNames.any(
                (t) => academicText(row['JSXM']).contains(t),
              );
        }).toList();
      }
      final manual = bindings[course.id];
      final reserved = bindings.entries
          .where((e) => e.key != course.id && validCourseIds.contains(e.key))
          .map((e) => e.value)
          .toSet();
      proposals[course.id] = manual != null && grouped.containsKey(manual)
          ? [manual]
          : candidates.where((key) => !reserved.contains(key)).toList();
    }
    return [
      for (final c in courses)
        if (proposals[c.id]?.length == 1 &&
            proposals.values
                    .where(
                      (p) =>
                          p.length == 1 && p.single == proposals[c.id]!.single,
                    )
                    .length ==
                1)
          c.withTimetables(
            tables(grouped[proposals[c.id]!.single]!),
            academic: true,
            group: proposals[c.id]!.single,
          )
        else
          c,
    ];
  }

  List<CatalogCourse> displayOnlyCourses(List<CatalogCourse> effective) {
    final bound = effective.map((c) => c.academicGroup).toSet();
    return [
      for (final e in groups.entries)
        if (!bound.contains(e.key))
          CatalogCourse(
            id: 'academic:${e.key}',
            title: academicText(e.value.first['KCMC']),
            courseCode: academicText(e.value.first['KCDM']),
            academicMatched: true,
            academicGroup: e.key,
            teachingClassName: academicText(e.value.first['BJMC']),
            instructorNames: [academicText(e.value.first['JSXM'])],
            timetables: tables(e.value),
          ),
    ];
  }

  Map<String, dynamic> toJson() => {
    'term': term,
    'anchorFromUser': anchorFromUser,
    'monday': monday.toIso8601String(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'rows': rows,
  };
  factory AcademicSchedule.fromJson(Map<String, dynamic> j) => AcademicSchedule(
    term: j['term'] as String,
    anchorFromUser: j['anchorFromUser'] == true,
    monday: DateTime.parse(j['monday'] as String),
    fetchedAt: DateTime.parse(j['fetchedAt'] as String),
    rows: (j['rows'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList(),
  );
}

abstract final class AcademicScheduleStore {
  static String key(int uid) => 'academic_schedule_v1_$uid';
  static Future<AcademicSchedule?> read(
    int uid, {
    bool reload = false,
    bool useUserStart = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    try {
      final raw = prefs.getString(key(uid));
      if (raw == null) return null;
      final parsed = AcademicSchedule.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (!useUserStart) return parsed;
      final manual = await SemesterPreferences.read(uid, parsed.term);
      final start =
          manual ??
          await platformSemesterMonday(uid, parsed.term) ??
          academicMondays[parsed.term] ??
          (parsed.anchorFromUser ? null : parsed.monday);
      if (start == null) return null;
      return AcademicSchedule(
        term: parsed.term,
        monday: start,
        fetchedAt: parsed.fetchedAt,
        rows: parsed.rows,
        anchorFromUser: parsed.anchorFromUser,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(int uid, AcademicSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key(uid), jsonEncode(schedule.toJson()))) {
      throw StateError('课表未能保存');
    }
  }
}

abstract final class AcademicBindings {
  static String key(int uid, String term) =>
      'academic_bindings_v1_${uid}_$term';
  static Future<Map<String, String>> read(int uid, String term) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return Map<String, String>.from(
        jsonDecode(prefs.getString(key(uid, term)) ?? '{}') as Map,
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> write(
    int uid,
    String term,
    Map<String, String> values,
  ) async {
    if (values.values.toSet().length != values.length) {
      throw const FormatException('同一教务教学班不能重复对应');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key(uid, term), jsonEncode(values))) {
      throw StateError('课程对应未能保存');
    }
  }
}

Future<CourseCatalogSnapshot?> readAcademicCatalog(int uid) async {
  final raw = await CourseCatalogStore.read(uid);
  if (raw == null) return null;
  final academic = await AcademicScheduleStore.read(uid);
  final courses = <CatalogCourse>[];
  for (final c in raw.courses) {
    courses.add(c.withMeetings(await CourseScheduleStore.read(uid, c.id)));
  }
  final effective = academic == null ? courses : academic.apply(courses);
  return CourseCatalogSnapshot(
    fetchedAt: raw.fetchedAt,
    academicTerm: raw.academicTerm,
    courses: effective,
    semesterId: raw.semesterId,
    academicYearId: raw.academicYearId,
    rolesResolved: raw.rolesResolved,
    startDatesResolved: raw.startDatesResolved,
    academicOnlyCourses: academic?.displayOnlyCourses(effective) ?? const [],
  );
}
