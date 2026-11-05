import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_models.dart';
import '../fixtures/ta_http_fixture.dart';

void main() {
  test(
    '111 final grades load in one bulk request without per-student reads',
    () async {
      final f = TaHttpFixture(studentCount: 111, submittedCount: 108);
      for (var id = 1; id <= 111; id++) {
        f.scores[id] = id == 111 ? 0 : 86.5;
      }
      final repo = await f.repository();
      addTearDown(repo.dispose);
      final rows = await repo.students(91, 81);
      expect(rows, hasLength(111));
      expect(rows.every((s) => s.scoreChecked), isTrue);
      expect(rows.first.score, 86.5);
      expect(rows.last.score, 0);
      expect(rows.last.submitted, isFalse);
      expect(f.requests.map((r) => r.uri.path), [
        '/api/course/91/students',
        '/api/homework/81/student-submissions',
        '/api/activities/81/homework-scores',
      ]);
      f.scores.clear();
      final empty = await repo.students(91, 81);
      expect(empty.every((s) => s.score == null && s.scoreChecked), isTrue);
    },
  );
  test(
    'final grade is authoritative, and malformed bulk responses fail as a whole',
    () async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      addTearDown(repo.dispose);
      List<Map<String, Object?>> grades = [
        {'activity_id': 81, 'student_id': 2, 'final_score': '0', 'score': '90'},
        {'activity_id': 81, 'student_id': 1, 'final_score': '88.5'},
      ];
      f.intercept = (r) async => r.uri.path.endsWith('/homework-scores')
          ? TaHttpFixture.response({'homework_scores': grades})
          : null;
      expect((await repo.students(91, 81)).map((s) => s.score), [
        88.5,
        0,
        null,
      ]);
      for (final bad in [
        {'activity_id': 82, 'student_id': 1, 'final_score': '80'},
        {'activity_id': 81, 'student_id': 1, 'final_score': 'NaN'},
        {'activity_id': 81, 'student_id': 1},
      ]) {
        grades = [bad];
        await expectLater(repo.students(91, 81), throwsFormatException);
      }
      grades = [
        {'activity_id': 81, 'student_id': 1, 'final_score': '80'},
        {'activity_id': 81, 'student_id': 1, 'final_score': '90'},
      ];
      await expectLater(repo.students(91, 81), throwsFormatException);
    },
  );
  test(
    'submission attachment bytes are independent of submission presence',
    () async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      addTearDown(repo.dispose);
      f.intercept = (r) async => r.uri.path.endsWith('/student-submissions')
          ? TaHttpFixture.response({
              'submissions': [
                {
                  'created_by': {'id': 1},
                  'attachments_size': 1048576,
                },
                {
                  'created_by': {'id': 2},
                },
              ],
            })
          : null;
      final rows = await repo.students(91, 81);
      expect(rows.map((s) => s.submitted), [true, true, false]);
      expect(rows.map((s) => s.attachmentBytes), [1048576, 0, 0]);
      expect(rows.first.hasAttachments, isTrue);
      expect(rows[1].hasAttachments, isFalse);
      expect(rows.first.withScore(80).attachmentBytes, 1048576);
      expect(taAttachmentSize(rows.first.attachmentBytes), '1 MB');
      expect(taAttachmentSize(1178), '1.15 KB');
      expect(taAttachmentSize(0), '无附件');
      expect(taAttachmentSize(null), '—');
      for (final bytes in [-1, 1.5, '100']) {
        f.intercept = (r) async => r.uri.path.endsWith('/student-submissions')
            ? TaHttpFixture.response({
                'submissions': [
                  {
                    'created_by': {'id': 1},
                    'attachments_size': bytes,
                  },
                ],
              })
            : null;
        await expectLater(repo.students(91, 81), throwsFormatException);
      }
    },
  );
  test(
    'score history uses complete pagination and latest record order for grading too',
    () async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      addTearDown(repo.dispose);
      f.intercept = (r) async => r.uri.path.endsWith('/score-records')
          ? TaHttpFixture.response({
              'pages': 2,
              'records': r.uri.queryParameters['page'] == '1'
                  ? [
                      {
                        'id': 2,
                        'created_at': '2026-11-01T10:00:00Z',
                        'old_final_score': 80,
                        'final_score': '90',
                        'operator_name': '示例助教',
                      },
                    ]
                  : [
                      {
                        'id': 1,
                        'created_at': '2026-11-01T10:00:00Z',
                        'old_final_score': null,
                        'final_score': 80,
                      },
                    ],
            })
          : null;
      final records = await repo.scoreRecords(81, 1);
      expect(records.map((r) => r.id), [2, 1]);
      expect(records.first.operatorName, '示例助教');
      expect(records.first.oldScore, 80);
      expect(records.last.oldScore, isNull);
      expect(await repo.currentScore(81, 1), 90);
      expect(f.requests, hasLength(4));
    },
  );
}
