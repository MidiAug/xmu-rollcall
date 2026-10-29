import 'package:xmu_rollcall/features/academic/academic_parsing.dart';

class AcademicCourseRow {
  const AcademicCourseRow({
    required this.courseId,
    this.courseName = '',
    this.teachingClassId,
    this.teachingClassName = '',
    this.instructor = '',
    this.room = '',
    this.weekday = 0,
    this.firstPeriod = 0,
    this.lastPeriod = 0,
    this.startMinute = 0,
    this.endMinute = 0,
    this.weeks = const {},
    this.reportedStart,
    this.reportedEnd,
  });

  final String courseId, courseName, teachingClassName, instructor, room;
  final int weekday, firstPeriod, lastPeriod, startMinute, endMinute;
  final Set<int> weeks;
  final String? teachingClassId, reportedStart, reportedEnd;
  String get groupKey => '$courseId/$teachingClassId';

  factory AcademicCourseRow.fromJson(Map<String, dynamic> row) {
    final mask = academicText(row['ZCBH']);
    return AcademicCourseRow(
      courseId: academicText(row['KCDM']),
      courseName: academicText(row['KCMC']),
      teachingClassId: row['BJDM']?.toString(),
      teachingClassName: academicText(row['BJMC']),
      instructor: academicText(row['JSXM']),
      room: academicText(row['JASMC']),
      weekday: academicInt(row['XQ']),
      firstPeriod: academicInt(row['KSJCDM']),
      lastPeriod: academicInt(row['JSJCDM']),
      startMinute: academicInt(row['startMinute']),
      endMinute: academicInt(row['endMinute']),
      weeks: mask.isEmpty ? const {} : Set.unmodifiable(academicWeeks(mask)),
      reportedStart: row['KSSJ']?.toString(),
      reportedEnd: row['JSSJ']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'KCDM': courseId,
    'KCMC': courseName,
    'BJDM': teachingClassId,
    'BJMC': teachingClassName,
    'JSXM': instructor,
    'JASMC': room,
    'XQ': weekday,
    'KSJCDM': firstPeriod,
    'JSJCDM': lastPeriod,
    'ZCBH': List.generate(
      weeks.fold(1, (n, w) => w > n ? w : n),
      (i) => weeks.contains(i + 1) ? '1' : '0',
    ).join(),
    'startMinute': startMinute,
    'endMinute': endMinute,
    'KSSJ': reportedStart,
    'JSSJ': reportedEnd,
  };
}
