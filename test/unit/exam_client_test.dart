import '../fixtures/exam_adapter.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import 'package:xmu_rollcall/features/exams/academic_exam_reader.dart';
import 'package:xmu_rollcall/features/exams/exam_models.dart';

void main() {
  Future<ExamSnapshot> fetch(ExamAdapter adapter) {
    final dio = Dio()..httpClientAdapter = adapter;
    return AcademicExamReader(
      AcademicSession(
        store: SecureStore.memory({SecureStore.keyUserId: '1'}),
        dio: dio,
        limiter: RateLimiter(minInterval: Duration.zero),
      ),
    ).fetch(
      1,
      term: '20261',
      at: DateTime(2026, 10, 31),
      username: 'synthetic',
    );
  }

  test(
    'current term only, complete paging, null dates and minimal cache',
    () async {
      final adapter = ExamAdapter();
      final result = await fetch(adapter);
      expect(result.exams.length, 3);
      final arranged = result.exams.first;
      expect(arranged.room, '测试楼A101');
      expect(arranged.seat, '12');
      expect(arranged.statusAt(DateTime(2026, 11, 10, 9)), ExamStatus.upcoming);
      expect(
        arranged.statusAt(DateTime(2026, 11, 10, 10)),
        ExamStatus.finished,
      );
      expect(
        result.exams
            .where((e) => e.statusAt(DateTime(2027)) == ExamStatus.unarranged)
            .length,
        2,
      );
      final persisted = jsonEncode(result.toJson());
      expect(persisted, isNot(contains('XH')));
      expect(persisted, isNot(contains('private_unneeded')));
      expect(ExamSnapshot.fromJson(jsonDecode(persisted)).exams.length, 3);
      final queries = adapter.requests.where(
        (r) =>
            r.uri.path.endsWith('/cxxsksap.do') ||
            r.uri.path.endsWith('/cxyxkwapkwdkc.do'),
      );
      expect(queries.length, 3);
      expect(
        queries.every((r) => (r.data as Map)['XNXQDM'] == '2026-2027-1'),
        isTrue,
      );
      expect(
        adapter.requests.first.uri.queryParameters['appId'],
        '4768687067472349',
      );
      for (final request in adapter.requests.where((r) => r.method == 'POST')) {
        expect(request.headers['Origin'], 'https://jw.xmu.edu.cn');
        expect(request.headers['Referer'], contains('/studentWdksapApp/'));
        expect(request.headers['X-Requested-With'], 'XMLHttpRequest');
      }
    },
  );
  test(
    'exam application verifies its own student without accessing GS context',
    () async {
      final adapter = ExamAdapter();
      await fetch(adapter);
      expect(
        adapter.requests.any((r) => r.uri.path.contains('/gsapp/')),
        isFalse,
      );
      expect(
        adapter.requests.any((r) => r.uri.path.endsWith('/cxxsjbxx.do')),
        isTrue,
      );
      await expectLater(
        fetch(ExamAdapter()..wrongStudent = true),
        throwsFormatException,
      );
    },
  );
  test(
    'current term with unarranged courses only remains a complete result',
    () async {
      final result = await fetch(ExamAdapter()..emptyArranged = true);
      expect(result.exams.length, 2);
      expect(result.exams.every((e) => e.date == null), isTrue);
    },
  );
  test('both successful empty lists are a valid snapshot', () async {
    final result = await fetch(ExamAdapter()..empty = true);
    expect(result.exams, isEmpty);
    expect(result.term, '20261');
  });
  for (final failure in [
    'identity',
    'term',
    'unarranged',
    'repeated',
    'date',
  ]) {
    test('rejects $failure instead of returning a partial success', () async {
      final adapter = ExamAdapter()
        ..wrongIdentity = failure == 'identity'
        ..wrongTerm = failure == 'term'
        ..failUnarranged = failure == 'unarranged'
        ..repeat = failure == 'repeated'
        ..invalidDate = failure == 'date';
      await expectLater(
        fetch(adapter),
        throwsA(
          failure == 'unarranged'
              ? isA<DioException>()
              : isA<FormatException>(),
        ),
      );
    });
  }
  test(
    'date-only records finish at the next day, not midnight at the start',
    () {
      final exam = parseAcademicExam({
        'KSRWID': 'x',
        'KCM': '课程',
        'KSRQ': '2026-11-10',
      });
      expect(
        exam.statusAt(DateTime(2026, 11, 10, 23, 59)),
        ExamStatus.upcoming,
      );
      expect(exam.statusAt(DateTime(2026, 11, 11)), ExamStatus.finished);
    },
  );
  test(
    'refresh cadence follows published calendar and upcoming exam facts',
    () {
      ExamSnapshot snapshot(
        DateTime at, {
        List<AcademicExam> exams = const [],
        String term = '20261',
      }) => ExamSnapshot(term: term, at: at, exams: exams);
      expect(
        examRefreshDue(
          snapshot(DateTime(2026, 10, 25)),
          DateTime(2026, 10, 31),
        ),
        isFalse,
      );
      expect(
        examRefreshDue(
          snapshot(DateTime(2026, 10, 24)),
          DateTime(2026, 10, 31),
        ),
        isTrue,
      );
      expect(
        examRefreshDue(
          snapshot(DateTime(2026, 12, 27)),
          DateTime(2026, 12, 28),
        ),
        isTrue,
      );
      final near = snapshot(
        DateTime(2026, 11, 9),
        exams: [
          parseAcademicExam({
            'KSRWID': 'x',
            'KCM': '课程',
            'KSRQ': '2026-11-10',
            'KSSJMS': '08:00-10:00',
          }),
        ],
      );
      expect(examRefreshDue(near, DateTime(2026, 11, 9, 5)), isFalse);
      expect(examRefreshDue(near, DateTime(2026, 11, 9, 6)), isTrue);
      expect(
        examRefreshDue(
          snapshot(DateTime(2026, 1), term: '20311'),
          DateTime(2031, 12),
        ),
        isFalse,
      );
      expect(
        examRefreshDue(snapshot(DateTime(2027, 1, 9)), DateTime(2027, 1, 11)),
        isFalse,
      );
    },
  );
}
