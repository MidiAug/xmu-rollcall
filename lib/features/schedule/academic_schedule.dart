import 'academic_course_row.dart';
import 'package:xmu_rollcall/features/academic/academic_parsing.dart';
export 'academic_course_row.dart';
export 'package:xmu_rollcall/features/academic/academic_parsing.dart';
import 'package:xmu_rollcall/features/schedule/academic_meetings.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';
import 'dart:convert';
import 'package:xmu_rollcall/core/cache/course_schedule_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

class AcademicSchedule {
  const AcademicSchedule({
    required this.term,
    required this.monday,
    required this.fetchedAt,
    required this.rows,
    this.anchorFromUser = false,
    this.studentCollege = '',
  });
  final String term;
  final DateTime monday;
  final DateTime fetchedAt;
  final bool anchorFromUser;
  final String studentCollege;

  /// Only course metadata; identity and credentials are never cached here.
  final List<AcademicCourseRow> rows;

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
    String studentCollege = '',
  }) {
    if (payload['success'] != true || payload['pkjgList'] is! List) {
      throw const FormatException('教务未返回完整课表');
    }
    final rows = <AcademicCourseRow>[];
    // The current published timetable already includes historical changes.
    for (final raw in payload['pkjgList'] as List) {
      final source = raw as Map;
      final start = clock[academicInt(source['KSJCDM'])];
      final end = clock[academicInt(source['JSJCDM'])];
      if (start == null || end == null) {
        throw const FormatException('教务课次时间不完整');
      }
      final row = AcademicCourseRow.fromJson({
        for (final key in fields) key: source[key],
        'startMinute': start.start,
        'endMinute': end.end,
      });
      if (row.startMinute >= row.endMinute ||
          row.weekday < 1 ||
          row.weekday > 7 ||
          row.courseId.isEmpty ||
          academicText(source['ZCBH']).isEmpty) {
        throw const FormatException('教务课次时间不完整');
      }
      rows.add(row);
    }
    return AcademicSchedule(
      term: term,
      monday: monday,
      fetchedAt: at,
      rows: rows,
      anchorFromUser: anchorFromUser,
      studentCollege: studentCollege,
    );
  }

  Map<String, List<AcademicCourseRow>> get groups {
    final result = <String, List<AcademicCourseRow>>{};
    for (final r in rows) {
      result.putIfAbsent(r.groupKey, () => []).add(r);
    }
    return result;
  }

  Map<int, List<TimetableSlot>> tables(List<AcademicCourseRow> entries) {
    final groups = <String, List<TimetableSlot>>{};
    final weekdays = <String, int>{};
    for (final r in entries) {
      final weeks = r.weeks;
      if (weeks.isEmpty) continue;
      final day = r.weekday;
      final key = '${r.groupKey}/$day';
      weekdays[key] = day;
      groups
          .putIfAbsent(key, () => [])
          .add(
            TimetableSlot(
              sequence: r.firstPeriod,
              endSequence: r.lastPeriod,
              start: DateTime(2000, 1, 3, 0, r.startMinute),
              end: DateTime(2000, 1, 3, 0, r.endMinute),
              classroom: r.room,
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
    String name(String v) => v
        .trim()
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
                course.courseCode?.isNotEmpty == true &&
                e.value.first.courseId == course.courseCode,
          )
          .map((e) => e.key)
          .toList();
      if (candidates.isEmpty) {
        candidates = grouped.entries
            .where((e) => name(e.value.first.courseName) == name(course.title))
            .map((e) => e.key)
            .toList();
      }
      if (candidates.length > 1) {
        candidates = candidates.where((key) {
          final row = grouped[key]!.first;
          return (course.teachingClassName?.isNotEmpty == true &&
                  name(row.teachingClassName) ==
                      name(course.teachingClassName!)) ||
              course.instructorNames.any((t) => row.instructor.contains(t));
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
            title: e.value.first.courseName,
            courseCode: e.value.first.courseId,
            academicMatched: true,
            academicGroup: e.key,
            teachingClassName: e.value.first.teachingClassName,
            instructorNames: [e.value.first.instructor],
            timetables: tables(e.value),
          ),
    ];
  }

  Map<String, dynamic> toJson() => {
    'term': term,
    'studentCollege': studentCollege,
    'anchorFromUser': anchorFromUser,
    'monday': monday.toIso8601String(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'rows': rows.map((row) => row.toJson()).toList(),
  };
  factory AcademicSchedule.fromJson(Map<String, dynamic> j) => AcademicSchedule(
    term: j['term'] as String,
    studentCollege: j['studentCollege'] as String? ?? '',
    anchorFromUser: j['anchorFromUser'] == true,
    monday: DateTime.parse(j['monday'] as String),
    fetchedAt: DateTime.parse(j['fetchedAt'] as String),
    rows: (j['rows'] as List)
        .map(
          (r) =>
              AcademicCourseRow.fromJson(Map<String, dynamic>.from(r as Map)),
        )
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
        studentCollege: parsed.studentCollege,
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

/// Project cached platform identities onto the academic term and timetable.
/// Old catalogs may contain every enrolled year even when requested as ongoing.
CourseCatalogSnapshot projectAcademicCatalog(
  CourseCatalogSnapshot raw,
  AcademicSchedule? academic, {
  DateTime? at,
}) {
  final term = academic?.term ?? currentSemester(at ?? DateTime.now());
  bool belongsToTerm(CatalogCourse c) {
    final code = c.courseCode ?? '';
    final short = RegExp(r'^(\d{4}[123])-').firstMatch(code);
    final long = RegExp(r'^(\d{4})(\d{4})([123])').firstMatch(code);
    final codedTerm =
        short?.group(1) ??
        (long != null && int.parse(long[2]!) == int.parse(long[1]!) + 1
            ? '${long[1]}${long[3]}'
            : null);
    if (codedTerm != null) return codedTerm == term;
    final start = c.startDate;
    return start == null || teachingMondayFromCourses([c], term) != null;
  }

  // No platform/local fallback: missing academic data means unknown class time.
  final courses = [
    for (final c in raw.courses.where(belongsToTerm))
      c.withTimetables(const {}, academic: false),
  ];
  final effective = academic?.apply(courses) ?? courses;
  return CourseCatalogSnapshot(
    fetchedAt: raw.fetchedAt,
    academicTerm: term,
    courses: effective,
    semesterId: raw.semesterId,
    academicYearId: raw.academicYearId,
    rolesResolved: raw.rolesResolved,
    startDatesResolved: raw.startDatesResolved,
    academicOnlyCourses: academic?.displayOnlyCourses(effective) ?? const [],
  );
}

Future<CourseCatalogSnapshot?> readAcademicCatalog(int uid) async {
  final raw = await CourseCatalogStore.read(uid);
  if (raw == null) return null;
  final academic = await AcademicScheduleStore.read(uid);
  final courses = [
    for (final c in raw.courses)
      c.withMeetings(await CourseScheduleStore.read(uid, c.id)),
  ];
  return projectAcademicCatalog(
    CourseCatalogSnapshot(
      fetchedAt: raw.fetchedAt,
      courses: courses,
      academicTerm: raw.academicTerm,
      rolesResolved: raw.rolesResolved,
      startDatesResolved: raw.startDatesResolved,
      semesterId: raw.semesterId,
      academicYearId: raw.academicYearId,
    ),
    academic,
  );
}
