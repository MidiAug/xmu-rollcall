import 'grade_release_policy.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import 'package:xmu_rollcall/features/academic/academic_parsing.dart';

class AcademicGradeResult {
  const AcademicGradeResult({
    required this.rows,
    required this.replacedTerms,
    this.education = 'undergraduate',
    this.complete = false,
    this.exams,
  });
  final List<Map<String, dynamic>> rows;
  final Set<String> replacedTerms;
  final String education;
  final bool complete;
  final AcademicExamDates? exams;
}

class AcademicGradeReader {
  AcademicGradeReader(this.session, {this.queryExams = false});
  final bool queryExams;
  final AcademicSession session;
  Uri? _applicationPage;
  String? _verifiedStudent;

  Future<AcademicGradeResult> fetch(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    bool recent = false,
  }) async {
    try {
      await session.connect(
        uid,
        applicationId: '4979568947762216',
        sso: sso,
        username: username,
        password: password,
      );
      final result = await _read(username: username, recent: recent);
      AcademicExamDates? exams;
      if (queryExams && result.education == 'undergraduate') {
        try {
          exams = await _readExamDates(_verifiedStudent!);
        } catch (_) {
          AppLog.event('grades.exams.unavailable');
        }
      }
      await session.persist(uid);
      return AcademicGradeResult(
        rows: result.rows,
        replacedTerms: result.replacedTerms,
        education: result.education,
        complete: result.complete,
        exams: exams,
      );
    } finally {
      session.close();
    }
  }

  Future<AcademicExamDates> _readExamDates(String username) async {
    const base = '/jwapp/sys/studentWdksapApp/';
    final at = DateTime.now();
    final term = currentSemester(at);
    final year = int.parse(term.substring(0, 4));
    final fullTerm = '$year-${year + 1}-${term[4]}';
    final page = AcademicSession.jw.resolve('$base*default/index.do');
    await session.open(page);
    final payload = await session.json(
      '${base}modules/wdksap/cxxsksap.do',
      data: {'XNXQDM': fullTerm, 'pageSize': 500, 'pageNumber': 1},
      headers: {
        'Referer': page.toString(),
        'Origin': AcademicSession.jw.origin,
        'X-Requested-With': 'XMLHttpRequest',
      },
    );
    final node = (payload['datas'] as Map?)?['cxxsksap'];
    if (node is! Map || node['rows'] is! List) {
      throw const FormatException('考试安排格式异常');
    }
    final rows = node['rows'] as List;
    if (node['totalSize'] is num && (node['totalSize'] as num) > rows.length) {
      throw const FormatException('考试安排不完整');
    }
    final dates = <DateTime>{};
    for (final row in rows) {
      if (row is! Map ||
          (row['XH'] != null && academicText(row['XH']) != username) ||
          (row['XNXQDM'] != null && academicText(row['XNXQDM']) != fullTerm)) {
        throw const FormatException('考试安排身份或学期不一致');
      }
      final raw = academicText(row['KSRQ']);
      final match = RegExp(
        r'^(\d{4})-(\d{2})-(\d{2})(?:$|[ T])',
      ).firstMatch(raw);
      if (match == null) throw const FormatException('考试日期格式异常');
      final date = DateTime(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
      );
      if (date.year != int.parse(match[1]!) ||
          date.month != int.parse(match[2]!) ||
          date.day != int.parse(match[3]!)) {
        throw const FormatException('考试日期无效');
      }
      dates.add(date);
    }
    return AcademicExamDates(term: term, at: at, dates: dates.toList()..sort());
  }

  Future<void> _openApplication(String applicationId) async {
    final page = await session.open(
      AcademicSession.jw
          .resolve('/appShow')
          .replace(queryParameters: {'appId': applicationId}),
    );
    if (page.path == '/jwapp/sys/cjcx/*default/index.do' ||
        page.path == '/gsapp/sys/wdcjapp/*default/index.do') {
      _applicationPage = page;
    }
  }

  Future<Map<String, dynamic>> _json(
    String path, {
    Map<String, dynamic>? data,
  }) => session.json(
    path,
    data: data,
    headers: {
      'Referer':
          (_applicationPage ??
                  AcademicSession.jw.resolve(
                    '/jwapp/sys/cjcx/*default/index.do',
                  ))
              .toString(),
      'Origin': AcademicSession.jw.origin,
      'X-Requested-With': 'XMLHttpRequest',
      'Accept': 'application/json, text/javascript, */*; q=0.01',
    },
  );

  Future<AcademicGradeResult> _read({
    String? username,
    required bool recent,
  }) async {
    final identity = await session.json('/gsapp/sys/wdkbapp/wdkcb/initXsxx.do');
    final person = identity['data'] is List
        ? (identity['data'] as List).singleOrNull
        : identity['data'];
    final student = person is Map ? academicText(person['XH']) : '';
    if (identity['success'] != true ||
        student.isEmpty ||
        (username != null && student != username)) {
      throw const FormatException('教务身份与所选账号不一致');
    }
    _verifiedStudent = student;
    try {
      await _openApplication('4768574631264620');
    } on AcademicApplicationDenied {
      await _openApplication('5094115980385668');
      return await _graduateGrades(student);
    }
    // The official grade page initializes the student's JW application role
    // before issuing queries; a valid CAS login alone does not do this.
    final role = await _json(
      '/jwapp/sys/jwpubapp/pub/setJwCommonAppRole.do',
      data: {},
    );
    if (role['success'] != true && '${role['success']}' != '1') {
      throw const FormatException('教务成绩应用初始化失败，请稍后重试');
    }
    const base = '/jwapp/sys/cjcx/modules/cjcx/';
    final terms = <String>{};
    if (recent) {
      final result = await _json('${base}cxdqxnxqhsygxnxq.do', data: {});
      final rows =
          ((result['datas'] as Map?)?['cxdqxnxqhsygxnxq'] as Map?)?['rows'];
      if (rows is! List || rows.isEmpty) {
        throw const FormatException('近两学期信息暂不可用');
      }
      for (final row in rows.whereType<Map>()) {
        final term = academicText(row['XNXQDM']);
        if (!RegExp(r'^\d{4}-\d{4}-[1239]$').hasMatch(term)) {
          throw const FormatException('成绩学期格式异常');
        }
        terms.add(term);
      }
      if (terms.isEmpty) throw const FormatException('近两学期信息暂不可用');
    }
    final output = <Map<String, dynamic>>[];
    final ids = <String>{};
    for (final term in recent ? terms.cast<String?>() : <String?>[null]) {
      var loaded = 0;
      for (var page = 1; page <= 100; page++) {
        final result = await _json(
          '${base}xscjcx.do',
          data: {
            'querySetting': jsonEncode([
              {
                'name': 'SFYX',
                'linkOpt': 'AND',
                'builder': 'm_value_equal',
                'value': '1',
              },
              {
                'name': 'SHOWMAXCJ',
                'linkOpt': 'AND',
                'builder': 'm_value_equal',
                'value': '0',
              },
              if (term != null)
                {
                  'name': 'XNXQDM',
                  'linkOpt': 'AND',
                  'builder': 'm_value_equal',
                  'value': term,
                },
            ]),
            '*order': '-XNXQDM,-KCH,-KXH',
            'pageSize': 999,
            'pageNumber': page,
          },
        );
        final node = (result['datas'] as Map?)?['xscjcx'];
        if (node is! Map || node['rows'] is! List) {
          throw const FormatException('成绩数据格式异常');
        }
        final meta = node['extParams'];
        if (meta is Map && meta['code'] != null && '${meta['code']}' != '1') {
          throw const FormatException('成绩查询未成功，请稍后重试');
        }
        final rows = (node['rows'] as List).whereType<Map>().toList();
        var added = 0;
        for (final row in rows) {
          if (row['XH'] != null && academicText(row['XH']) != student) {
            throw const FormatException('成绩数据身份不一致');
          }
          final id = academicText(row['WID']);
          if (id.isEmpty) throw const FormatException('成绩记录缺少标识');
          if (!ids.add(id)) continue;
          added++;
          // Minimized local data: no student number, identity or session fields.
          output.add({
            for (final key in [
              'WID',
              'KCH',
              'KCM',
              'XSKCM',
              'XNXQDM',
              'XNXQDM_DISPLAY',
              'XF',
              'JDF',
              'XFJD',
              'ZCJ',
              'DJCJMC',
              'SFYX',
              'XSZCJMC',
              'DJCJLXDM',
              'DJCJLXDM_DISPLAY',
              'KCXZDM_DISPLAY',
              'KCLBDM_DISPLAY',
              'XDFSDM_DISPLAY',
              'SFZX_DISPLAY',
            ])
              key: row[key],
          });
        }
        loaded += rows.length;
        final total = academicInt(node['totalSize']);
        if (loaded >= total) break;
        if (rows.isEmpty || added == 0 || page == 100) {
          throw const FormatException('成绩分页不完整，请稍后重试');
        }
      }
    }
    return AcademicGradeResult(rows: output, replacedTerms: terms);
  }

  /// Graduate application uses a different model and publishes no rows before grades exist.
  Future<AcademicGradeResult> _graduateGrades(String student) async {
    final output = <Map<String, dynamic>>[];
    final pages = <String>{};
    final occurrences = <String, int>{};
    var loaded = 0;
    for (var page = 1; page <= 100; page++) {
      final result = await _json(
        '/gsapp/sys/wdcjapp/modules/wdcj/xscjcx_by.do',
        data: {'pageSize': 100, 'pageNumber': page},
      );
      final node = (result['datas'] as Map?)?['xscjcx_by'];
      if (node is! Map ||
          node['rows'] is! List ||
          result['success'] == false ||
          (result['code'] != null && '${result['code']}' != '0')) {
        throw const FormatException('研究生成绩数据格式异常');
      }
      final rows = (node['rows'] as List).whereType<Map>().toList();
      if (rows.length != (node['rows'] as List).length) {
        throw const FormatException('研究生成绩记录格式异常');
      }
      if (!pages.add(
            sha256.convert(utf8.encode(jsonEncode(rows))).toString(),
          ) &&
          rows.isNotEmpty) {
        throw const FormatException('研究生成绩分页不完整');
      }
      for (final row in rows) {
        if (row['XH'] != null && academicText(row['XH']) != student) {
          throw const FormatException('成绩数据身份不一致');
        }
        final rawTerm = academicText(row['XNXQDM']);
        final short = RegExp(r'^(\d{4})([1239])$').firstMatch(rawTerm);
        final term = short == null
            ? rawTerm
            : '${short[1]}-${int.parse(short[1]!) + 1}-${short[2]}';
        final minimal = <String, dynamic>{
          'KCH': row['KCDM'],
          'KCM': row['KCMC'],
          'XNXQDM': term,
          'XF': row['XF'],
          'JDF': row['JDZ'],
          'ZCJ': row['CJ'],
          'XSZCJMC': row['CJXSZ'] ?? row['CJ'],
          'SFYX': row['SFYX'] ?? '1',
          'DJCJLXDM_DISPLAY': row['CJFZDM_DISPLAY'],
          'KCLBDM_DISPLAY': row['KCLBDM_DISPLAY'],
          'GRADE_SYSTEM': 'graduate',
        };
        final base = sha256
            .convert(
              utf8.encode(
                jsonEncode([
                  minimal,
                  row['KSXZDM'],
                  row['BJDM'],
                  row['ZTDM'],
                  row['TSZTDM'],
                ]),
              ),
            )
            .toString();
        final occurrence = occurrences.update(
          base,
          (n) => n + 1,
          ifAbsent: () => 0,
        );
        minimal['WID'] = academicText(row['WID']).isNotEmpty
            ? 'gs:${row['WID']}'
            : 'gs:$base:$occurrence';
        output.add(minimal);
      }
      loaded += rows.length;
      final total = academicInt(node['totalSize']);
      if (loaded >= total) {
        return AcademicGradeResult(
          rows: output,
          replacedTerms: const {},
          education: 'graduate',
          complete: true,
        );
      }
      if (rows.isEmpty || page == 100) {
        throw const FormatException('研究生成绩分页不完整');
      }
    }
    throw const FormatException('研究生成绩分页不完整');
  }
}
