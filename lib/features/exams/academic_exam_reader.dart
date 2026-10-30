import 'package:cookie_jar/cookie_jar.dart';
import 'package:xmu_rollcall/features/academic/academic_parsing.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import 'exam_models.dart';

const _base = '/jwapp/sys/studentWdksapApp/';
final _page = AcademicSession.jw.resolve('$_base*default/index.do');
final _headers = <String, dynamic>{
  'Referer': _page.toString(),
  'Origin': AcademicSession.jw.origin,
  'X-Requested-With': 'XMLHttpRequest',
};

String fullExamTerm(String term) {
  if (!RegExp(r'^\d{4}[123]$').hasMatch(term)) {
    throw const FormatException('考试学期格式异常');
  }
  final year = int.parse(term.substring(0, 4));
  return '$year-${year + 1}-${term[4]}';
}

Future<List<AcademicExam>> readAcademicExams(
  AcademicSession session,
  String student,
  String term, {
  bool unarranged = false,
}) async {
  final block = unarranged ? 'cxyxkwapkwdkc' : 'cxxsksap';
  final output = <AcademicExam>[];
  final ids = <String>{};
  final fullTerm = fullExamTerm(term);
  for (var page = 1; page <= 100; page++) {
    final payload = await session.json(
      '${_base}modules/wdksap/$block.do',
      data: {'XNXQDM': fullTerm, 'pageSize': 100, 'pageNumber': page},
      headers: _headers,
    );
    final datas = payload['datas'];
    final node = datas is Map ? datas[block] : null;
    if (node is! Map ||
        node['rows'] is! List ||
        payload['success'] == false ||
        (payload['code'] != null && '${payload['code']}' != '0')) {
      throw const FormatException('考试安排格式异常');
    }
    final meta = node['extParams'];
    if (meta is Map && meta['code'] != null && '${meta['code']}' != '1') {
      throw const FormatException('考试安排查询失败');
    }
    final rows = node['rows'] as List;
    final total = int.tryParse('${node['totalSize']}');
    if (total == null || total < 0) throw const FormatException('考试分页格式异常');
    for (final row in rows) {
      if (row is! Map ||
          (row['XH'] != null && academicText(row['XH']) != student) ||
          (row['XNXQDM'] != null && academicText(row['XNXQDM']) != fullTerm)) {
        throw const FormatException('考试安排身份或学期不一致');
      }
      final exam = parseAcademicExam(row, unarranged: unarranged);
      if (!ids.add(exam.id)) throw const FormatException('考试分页重复');
      output.add(exam);
    }
    if (output.length == total) return output;
    if (rows.isEmpty || output.length > total) break;
  }
  throw const FormatException('考试安排分页不完整');
}

class AcademicExamReader {
  AcademicExamReader(this.session);
  final AcademicSession session;

  Future<ExamSnapshot> fetch(
    int uid, {
    required String term,
    required DateTime at,
    CookieJar? sso,
    String? username,
    String? password,
  }) async {
    try {
      await session.connect(
        uid,
        applicationId: '4768687067472349',
        sso: sso,
        username: username,
        password: password,
      );
      final identity = await session.json(
        '${_base}modules/wdksap/cxxsjbxx.do',
        data: {},
        headers: _headers,
      );
      final datas = identity['datas'];
      final node = datas is Map ? datas['cxxsjbxx'] : null;
      final rows = node is Map ? node['rows'] : null;
      final person = rows is List ? rows.singleOrNull : null;
      final student = person is Map ? academicText(person['XH']) : '';
      if ('${identity['code']}' != '0' ||
          node is! Map ||
          '${node['totalSize']}' != '1' ||
          student.isEmpty ||
          (username != null && student != username)) {
        throw const FormatException('教务身份与所选账号不一致');
      }
      final role = await session.json(
        '/jwapp/sys/jwpubapp/pub/setJwCommonAppRole.do',
        data: {},
        headers: _headers,
      );
      if (role['success'] != true && '${role['success']}' != '1') {
        throw const FormatException('考试应用初始化失败');
      }
      final arranged = await readAcademicExams(session, student, term);
      final unarranged = await readAcademicExams(
        session,
        student,
        term,
        unarranged: true,
      );
      final undatedCodes = arranged
          .where((e) => e.date == null && e.courseCode.isNotEmpty)
          .map((e) => e.courseCode)
          .toSet();
      await session.persist(uid);
      return ExamSnapshot(
        term: term,
        at: at,
        exams: [
          ...arranged,
          ...unarranged.where((e) => !undatedCodes.contains(e.courseCode)),
        ],
      );
    } on AcademicApplicationDenied {
      throw const FormatException('当前账号无本科考试安排权限，研究生考试接口尚未接入');
    } finally {
      session.close();
    }
  }
}
