import 'package:cookie_jar/cookie_jar.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import 'academic_schedule.dart';
import 'academic_calendar.dart';
import 'semester_preferences.dart';

class AcademicTimetableReader {
  AcademicTimetableReader(this.session);
  final AcademicSession session;

  Future<AcademicSchedule> fetch(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    try {
      await session.connect(
        uid,
        applicationId: '4979568947762216',
        sso: sso,
        username: username,
        password: password,
      );
      const base = '/gsapp/sys/wdkbapp/';
      final identity = await session.json('${base}wdkcb/initXsxx.do');
      final rawPerson = identity['data'];
      final person = rawPerson is List && rawPerson.length == 1
          ? rawPerson.single
          : rawPerson;
      final student = person is Map ? academicText(person['XH']) : '';
      if (identity['success'] != true ||
          student.isEmpty ||
          (username != null && student != username)) {
        throw const FormatException('教务身份与登录账号不一致');
      }
      final terms = await session.json(
        '${base}modules/xskcb/kfdxnxqcx.do',
        data: {},
      );
      final available =
          ((terms['datas'] as Map?)?['kfdxnxqcx'] as Map?)?['rows'] as List?;
      final term = selectAcademicTerm(available ?? [], now);
      final week = await session.json(
        '${base}wdkcb/getZcxx.do',
        data: {'XNXQDM': term},
      );
      final currentWeek = academicInt(week['currentZc']);
      if (week['success'] != true || currentWeek < 1 || currentWeek > 30) {
        throw const FormatException('教务当前周次不可用');
      }
      final cached = await AcademicScheduleStore.read(uid, useUserStart: false);
      late final DateTime monday;
      var anchorFromUser = false;
      try {
        monday = academicMonday(
          term,
          currentWeek,
          now,
          cached: cached?.term == term && cached?.anchorFromUser != true
              ? cached!.monday
              : null,
        );
      } on AcademicCalendarUnavailable {
        final manual = await SemesterPreferences.read(uid, term);
        if (manual == null) rethrow;
        monday = manual;
        anchorFromUser = true;
      }
      final periods = await session.json(
        '${base}wdkcb/queryXsskjc.do',
        data: {'XNXQDM': term, 'XH': student},
      );
      final clock = <int, ({int start, int end})>{
        for (final p in periods['data'] as List? ?? const [])
          academicInt((p as Map)['DM']): (
            start: academicMinute(p['KSSJ']),
            end: academicMinute(p['JSSJ']),
          ),
      };
      final payload = await session.json(
        '${base}wdkcb/queryXspkjg.do',
        data: {'XNXQDM': term, 'XH': student},
      ); // No ZC: entire semester.
      final schedule = AcademicSchedule.parse(
        term: term,
        monday: monday,
        at: now,
        payload: payload,
        studentCollege: academicStudentCollege(person),
        clock: clock,
        anchorFromUser: anchorFromUser,
      );
      await session.persist(uid);
      return schedule;
    } finally {
      session.close();
    }
  }
}

/// Future published terms must not displace this season's term.
String selectAcademicTerm(List rows, DateTime now) {
  final year = now.month >= 8 ? now.year : now.year - 1;
  final season = now.month >= 8 || now.month == 1
      ? 1
      : now.month >= 7
      ? 3
      : 2;
  var ceiling = '$year$season';
  // Resolve early-published spring/summer schedules against actual teaching starts.
  final known =
      academicMondays.entries.where((e) => !e.value.isAfter(now)).toList()
        ..sort((a, b) => a.value.compareTo(b.value));
  if (known.isNotEmpty && academicMondays.containsKey('$year$season')) {
    ceiling = known.last.key;
  }
  final codes =
      rows
          .map((r) => academicText((r as Map)['XNXQDM']))
          .where(
            (c) =>
                RegExp(r'^\d{4}[123]$').hasMatch(c) &&
                c.compareTo(ceiling) <= 0,
          )
          .toList()
        ..sort();
  if (codes.isEmpty || codes.last != ceiling) {
    throw const FormatException('本学期课表尚未开放，请稍后刷新');
  }
  return codes.last;
}
