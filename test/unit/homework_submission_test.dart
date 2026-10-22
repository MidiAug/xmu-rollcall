import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';

void main() {
  HomeworkSubmissionState parse(List<Map<String, dynamic>> rows) =>
      HomeworkSubmissionState.parse({'list': rows});
  test(
    'empty personal list is unsubmitted, malformed data never means unsubmitted',
    () {
      expect(parse([]).submission, HomeworkSubmission.unsubmitted);
      expect(() => HomeworkSubmissionState.parse({}), throwsFormatException);
    expect(() => HomeworkSubmissionState.parse({'list': ['invalid']}), throwsFormatException);
      expect(parse([{}]).submission, HomeworkSubmission.unknown);
    },
  );
  test('draft is not a formal submission', () {
    expect(
      parse([
        {'is_draft': true, 'submitted_at': '2026-10-22'},
      ]).submission,
      HomeworkSubmission.draft,
    );
  });
  test(
    'unpublished grades are not labelled ungraded and never expose hidden scores',
    () {
      final state = parse([
        {
          'is_draft': false,
          'is_announce_score_time_passed': false,
          'score': 90,
        },
      ]);
      expect(state.submission, HomeworkSubmission.submitted);
      expect(state.grading, HomeworkGrading.unpublished);
      expect(state.score, isNull);
      expect(state.gradingLabel, '成绩未公布');
    },
  );
  test(
    'zero is graded, and latest formal version wins over old grades and drafts',
    () {
      final state = parse([
        {'is_draft': false, 'score': 95, 'submitted_at': '2026-10-20'},
        {
          'is_draft': false,
          'score': 0,
          'submitted_at': '2026-10-21',
          'is_latest_version': true,
          'is_announce_score_time_passed': true,
        },
        {'is_draft': true, 'submitted_at': '2026-10-22'},
      ]);
      expect(state.grading, HomeworkGrading.graded);
      expect(state.gradingLabel, '已批改 0 分');
      final restored = HomeworkSubmissionState.fromJson(state.toJson());
      expect(restored.score, 0);
      expect(restored.grading, HomeworkGrading.graded);
    },
  );
  test(
    'published empty score is pending; absent visibility information stays unknown',
    () {
      expect(
        parse([
          {
            'is_draft': false,
            'score': null,
            'score_at': null,
            'is_announce_score_time_passed': true,
          },
        ]).grading,
        HomeworkGrading.pending,
      );
      expect(
        parse([
          {'is_draft': false},
        ]).grading,
        HomeworkGrading.unknown,
      );
    },
  );
}
