import 'package:xmu_rollcall/features/academic/academic_parsing.dart';
import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';

enum ExamStatus { unarranged, upcoming, finished }

class AcademicExam {
  const AcademicExam({
    required this.id,
    required this.course,
    this.courseCode = '',
    this.date,
    this.start,
    this.end,
    this.room = '',
    this.seat = '',
    this.mode = '',
    this.name = '',
  });
  final String id, course, courseCode, room, seat, mode, name;
  final DateTime? date, start, end;

  ExamStatus statusAt(DateTime now) {
    final day = date;
    if (day == null) return ExamStatus.unarranged;
    // A missing time is not midnight: retain the exam for the entire day.
    final finish = end ?? DateTime(day.year, day.month, day.day + 1);
    return now.isBefore(finish) ? ExamStatus.upcoming : ExamStatus.finished;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'course': course,
    'code': courseCode,
    'date': date?.toIso8601String(),
    'start': start?.toIso8601String(),
    'end': end?.toIso8601String(),
    'room': room,
    'seat': seat,
    'mode': mode,
    'name': name,
  };
  factory AcademicExam.fromJson(Map<String, dynamic> json) => AcademicExam(
    id: json['id'] as String,
    course: json['course'] as String,
    courseCode: json['code'] as String,
    date: json['date'] == null ? null : DateTime.parse(json['date'] as String),
    start: json['start'] == null
        ? null
        : DateTime.parse(json['start'] as String),
    end: json['end'] == null ? null : DateTime.parse(json['end'] as String),
    room: json['room'] as String,
    seat: json['seat'] as String,
    mode: json['mode'] as String,
    name: json['name'] as String,
  );
}

AcademicExam parseAcademicExam(Map row, {bool unarranged = false}) {
  final course = academicText(row['KCM']).isNotEmpty
      ? academicText(row['KCM'])
      : academicText(row['KCMC']);
  final code = academicText(row['KCH']);
  final id = unarranged
      ? 'unarranged:${code.isEmpty ? course : code}'
      : academicText(row['KSRWID']).isNotEmpty
      ? academicText(row['KSRWID'])
      : academicText(row['KSDM']);
  if (id.isEmpty || course.isEmpty) {
    throw const FormatException('考试记录缺少课程或标识');
  }
  DateTime? date, start, end;
  final raw = academicText(row['KSRQ']);
  if (!unarranged && raw.isNotEmpty) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:$|[ T])').firstMatch(raw);
    if (match == null) throw const FormatException('考试日期格式异常');
    final y = int.parse(match[1]!),
        m = int.parse(match[2]!),
        d = int.parse(match[3]!);
    date = DateTime(y, m, d);
    if (date.year != y || date.month != m || date.day != d) {
      throw const FormatException('考试日期无效');
    }
    final range = RegExp(
      r'(\d{1,2}):(\d{2})\s*[-—–~至]\s*(\d{1,2}):(\d{2})',
    ).firstMatch(academicText(row['KSSJMS']));
    if (range != null) {
      final sh = int.parse(range[1]!), sm = int.parse(range[2]!);
      final eh = int.parse(range[3]!), em = int.parse(range[4]!);
      if (sh > 23 ||
          eh > 23 ||
          sm > 59 ||
          em > 59 ||
          eh * 60 + em <= sh * 60 + sm) {
        throw const FormatException('考试时间无效');
      }
      start = DateTime(y, m, d, sh, sm);
      end = DateTime(y, m, d, eh, em);
    }
  }
  return AcademicExam(
    id: id,
    course: course,
    courseCode: code,
    date: date,
    start: start,
    end: end,
    room: academicText(row['JASMC']),
    seat: academicText(row['ZWH']),
    mode: academicText(row['KSXS_DISPLAY']),
    name: academicText(row['KSMC']),
  );
}

class ExamSnapshot {
  const ExamSnapshot({
    required this.term,
    required this.at,
    required this.exams,
  });
  final String term;
  final DateTime at;
  final List<AcademicExam> exams;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'term': term,
    'at': at.toIso8601String(),
    'exams': exams.map((e) => e.toJson()).toList(),
  };
  factory ExamSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        !RegExp(r'^\d{4}[123]$').hasMatch(json['term'] as String)) {
      throw const FormatException('考试缓存版本或学期异常');
    }
    return ExamSnapshot(
      term: json['term'] as String,
      at: DateTime.parse(json['at'] as String),
      exams: (json['exams'] as List)
          .map(
            (e) => AcademicExam.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
    );
  }
}

Duration? examRefreshInterval(ExamSnapshot snapshot, DateTime now) {
  for (final exam in snapshot.exams) {
    final day = exam.start ?? exam.date;
    if (day != null &&
        exam.statusAt(now) == ExamStatus.upcoming &&
        day.difference(now) <= const Duration(hours: 48)) {
      return const Duration(hours: 6);
    }
  }
  final calendar = academicTerms[snapshot.term];
  if (calendar == null) return null; // Unknown calendar: explicit refresh only.
  if (now.isAfter(
    DateTime(calendar.end.year, calendar.end.month, calendar.end.day + 1),
  )) {
    return null;
  }
  // The final two calendar weeks, rather than a hard-coded week 16.
  final finalWeeks = calendar.end.subtract(
    Duration(days: calendar.end.weekday - 1 + 7),
  );
  return now.isBefore(finalWeeks)
      ? const Duration(days: 7)
      : const Duration(days: 1);
}

bool examRefreshDue(ExamSnapshot snapshot, DateTime now) {
  final interval = examRefreshInterval(snapshot, now);
  return interval != null &&
      (now.isBefore(snapshot.at) || now.difference(snapshot.at) >= interval);
}
