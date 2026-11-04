import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_batch.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_csv.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_models.dart';
import '../fixtures/ta_http_fixture.dart';

void main() {
  const students = [
    TaStudent(id: 1, number: '0001', name: 'A', submitted: true),
    TaStudent(id: 2, number: '0002', name: 'B', submitted: true),
    TaStudent(id: 3, number: '0003', name: 'C'),
  ];
  test(
    'CSV preserves zero-prefixed numbers, quoted fields, BOM and zero scores',
    () {
      final rows = parseTaCsv(
        '\uFEFFscore,user_no\r\n"0","0001"\r\n86.5,0002\r\n',
        students,
      );
      expect(rows.map((r) => r.issue), everyElement(isNull));
      expect(rows.first.student!.id, 1);
      expect(rows.first.score, '0');
      expect(rows.last.score, '86.5');
    },
  );
  test(
    'CSV rejects duplicates on every row, missing students and invalid scores',
    () {
      final rows = parseTaCsv(
        'user_no,score\n0001,80\n0001,90\nnone,70\n0002,\n0003,NaN',
        students,
      );
      expect(rows.every((r) => r.issue != null), isTrue);
      expect(rows.take(2).map((r) => r.issue), everyElement('学号重复'));
      for (final text in [
        'user_no,score\n"0001,80',
        'user_no,score,extra\n0001,1,x',
        'user_no,score\n"0001"x,80',
      ]) {
        expect(() => parseTaCsv(text, students), throwsFormatException);
      }
      for (final score in ['-1', '101', 'Infinity', '1e2', '=1+1', '']) {
        expect(
          parseTaCsv('user_no,score\n0001,$score', students).single.issue,
          isNotNull,
        );
      }
    },
  );
  test(
    'roster joins submissions by created_by.id rather than submission id',
    () async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      final rows = await repo.students(91, 81);
      expect(rows.map((s) => s.submitted), [true, true, false]);
      final assignments = await repo.assignments(91);
      expect(assignments.single.submitted, 2);
      expect((await repo.detail(91, 81)).canGrade, isTrue);
      f.group = true;
      expect((await repo.detail(91, 81)).canGrade, isFalse);
      await expectLater(repo.detail(92, 81), throwsFormatException);
      repo.dispose();
    },
  );
  test(
    'grade batch skips existing and unsubmitted; saves and verifies explicit zero',
    () async {
      final f = TaHttpFixture()..scores[2] = 79;
      final repo = await f.repository();
      final rows = parseTaCsv(
        'user_no,score\n0001,0\n0002,88\n0003,90',
        students,
      );
      final batch = TaGradeBatch();
      await batch.run(
        repository: repo,
        activityId: 81,
        rows: rows,
        overwrite: false,
        allowUnsubmitted: false,
        onChanged: () {},
      );
      expect(rows.map((r) => r.status), [
        TaRowStatus.saved,
        TaRowStatus.skipped,
        TaRowStatus.skipped,
      ]);
      final writes = f.requests.where((r) => r.method == 'PUT').toList();
      expect(writes, hasLength(1));
      expect(writes.single.data, {'student_id': 1, 'score': '0'});
      expect(writes.single.extra['retrySafe'], isFalse);
      expect(f.scores, {1: 0, 2: 79});
      await batch.run(
        repository: repo,
        activityId: 81,
        rows: rows,
        overwrite: true,
        allowUnsubmitted: true,
        onChanged: () {},
      );
      expect(f.requests.where((r) => r.method == 'PUT'), hasLength(1));
      repo.dispose();
    },
  );
  test(
    'explicit overwrite and unsubmitted option permit only confirmed rows',
    () async {
      final f = TaHttpFixture()..scores[2] = 79;
      final repo = await f.repository();
      final rows = parseTaCsv('user_no,score\n0002,88\n0003,90', students);
      await TaGradeBatch().run(
        repository: repo,
        activityId: 81,
        rows: rows,
        overwrite: true,
        allowUnsubmitted: true,
        onChanged: () {},
      );
      expect(rows.every((r) => r.status == TaRowStatus.saved), isTrue);
      expect(f.scores, {2: 88, 3: 90});
      repo.dispose();
    },
  );
  test(
    'ambiguous write failure stops batch without retry or next student',
    () async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      f.intercept = (options) async {
        if (options.method == 'PUT') {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return null;
      };
      final rows = parseTaCsv('user_no,score\n0001,80\n0002,90', students);
      await TaGradeBatch().run(
        repository: repo,
        activityId: 81,
        rows: rows,
        overwrite: false,
        allowUnsubmitted: false,
        onChanged: () {},
      );
      expect(rows.first.status, TaRowStatus.uncertain);
      expect(rows.last.status, TaRowStatus.ready);
      expect(f.requests.where((r) => r.method == 'PUT'), hasLength(1));
      repo.dispose();
    },
  );
  test('failed verification after a successful PUT stays uncertain', () async {
    final f = TaHttpFixture();
    final repo = await f.repository();
    f.intercept = (o) async => o.uri.path.endsWith('/score-records')
        ? TaHttpFixture.response({'pages': 1, 'records': []})
        : null;
    final rows = parseTaCsv('user_no,score\n0001,80\n0002,90', students);
    await TaGradeBatch().run(
      repository: repo,
      activityId: 81,
      rows: rows,
      overwrite: false,
      allowUnsubmitted: false,
      onChanged: () {},
    );
    expect(rows.first.status, TaRowStatus.uncertain);
    expect(f.scores[1], 80);
    expect(f.scores.containsKey(2), isFalse);
    repo.dispose();
  });
  test('session changes during preflight prevent the write', () async {
    final f = TaHttpFixture();
    final repo = await f.repository();
    final entered = Completer<void>();
    final release = Completer<void>();
    f.intercept = (o) async {
      if (o.uri.path.endsWith('/score-records')) {
        entered.complete();
        await release.future;
      }
      return null;
    };
    final rows = parseTaCsv('user_no,score\n0001,80', students);
    final run = TaGradeBatch().run(
      repository: repo,
      activityId: 81,
      rows: rows,
      overwrite: true,
      allowUnsubmitted: true,
      onChanged: () {},
    );
    await entered.future;
    await repo.http.clearSession();
    release.complete();
    await run;
    expect(f.requests.where((r) => r.method == 'PUT'), isEmpty);
    repo.dispose();
  });
  test(
    'lost permission during readback after accepted save is uncertain, not rejected',
    () async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      var reads = 0;
      f.intercept = (o) async {
        if (o.uri.path.endsWith('/score-records') && ++reads == 2) {
          return TaHttpFixture.response({}, 403);
        }
        return null;
      };
      final rows = parseTaCsv('user_no,score\n0001,80\n0002,90', students);
      await TaGradeBatch().run(
        repository: repo,
        activityId: 81,
        rows: rows,
        overwrite: false,
        allowUnsubmitted: false,
        onChanged: () {},
      );
      expect(f.scores[1], 80);
      expect(rows.first.status, TaRowStatus.uncertain);
      expect(f.scores.containsKey(2), isFalse);
      repo.dispose();
    },
  );
  test(
    'disposing a page cancels a queued PUT before adapter dispatch',
    () async {
      final f = TaHttpFixture();
      final repo = await f.repository(
        limiter: RateLimiter(minInterval: const Duration(milliseconds: 50)),
      );
      await repo.zipStatus(81);
      final child = repo.fork();
      final write = child.saveScore(81, 1, '80');
      final assertion = expectLater(write, throwsA(anything));
      child.dispose();
      await assertion;
      expect(f.requests.where((r) => r.method == 'PUT'), isEmpty);
      repo.dispose();
    },
  );
  test(
    'pack sends selected student ids and full roster; status key forms media URL',
    () async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      await repo.startZip(81, [2], [1, 2, 3]);
      final data = f.requests.single.data as Map;
      expect(data['ids'], [2]);
      expect(data['all_ids'], [1, 2, 3]);
      expect(data['column_setting'], containsPair('showUserNo', true));
      expect(
        (await repo.zipStatus(81)).download.toString(),
        'https://c-media.xmu.edu.cn/download/file/${'a' * 40}',
      );
      f.zip = null;
      expect((await repo.zipStatus(81)).download, isNull);
      await expectLater(
        repo.startZip(81, [9], [1, 2, 3]),
        throwsFormatException,
      );
      expect(
        () => TaZip.parse({
          'zip': {'id': 2, 'status': 'ready', 'key': 'https://evil.example'},
        }),
        throwsFormatException,
      );
      repo.dispose();
    },
  );
}
