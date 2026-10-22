enum HomeworkSubmission { unknown, unsubmitted, draft, submitted }

enum HomeworkGrading { unknown, pending, unpublished, graded }

class HomeworkSubmissionState {
  const HomeworkSubmissionState({
    required this.submission,
    this.grading = HomeworkGrading.unknown,
    this.score,
  });
  final HomeworkSubmission submission;
  final HomeworkGrading grading;
  final num? score;

  String get submissionLabel => switch (submission) {
    HomeworkSubmission.unknown => '提交状态未知',
    HomeworkSubmission.unsubmitted => '未提交',
    HomeworkSubmission.draft => '草稿未提交',
    HomeworkSubmission.submitted => '已提交',
  };
  String? get gradingLabel => submission != HomeworkSubmission.submitted
      ? null
      : switch (grading) {
          HomeworkGrading.unknown => null,
          HomeworkGrading.pending => '未批改',
          HomeworkGrading.unpublished => '成绩未公布',
          HomeworkGrading.graded =>
            score == null
                ? '已批改'
                : '已批改 ${score!.toString().replaceFirst(RegExp(r'\.0$'), '')} 分',
        };

  static HomeworkSubmissionState parse(Object? payload) {
    if (payload is! Map || payload['list'] is! List) {
      throw const FormatException('提交记录格式不支持');
    }
    final rows = (payload['list'] as List).whereType<Map>().toList();
    if (rows.length != (payload['list'] as List).length) {
      throw const FormatException('提交记录格式不支持');
    }
    if (rows.isEmpty) {
      return const HomeworkSubmissionState(
        submission: HomeworkSubmission.unsubmitted,
      );
    }
    final formal = rows
        .where(
          (r) =>
              r['is_draft'] == false ||
              (r['is_draft'] != true &&
                  (r['marked_submitted'] == true || r['submitted_at'] != null)),
        )
        .toList();
    if (formal.isEmpty) {
      return HomeworkSubmissionState(
        submission: rows.any((r) => r['is_draft'] == true)
            ? HomeworkSubmission.draft
            : HomeworkSubmission.unknown,
      );
    }
    formal.sort(
      (a, b) => '${b['submitted_at'] ?? b['created_at'] ?? ''}'.compareTo(
        '${a['submitted_at'] ?? a['created_at'] ?? ''}',
      ),
    );
    final latest = formal.firstWhere(
      (r) => r['is_latest_version'] == true,
      orElse: () => formal.first,
    );
    final rawScore = latest['final_score'] ?? latest['score'];
    final score = rawScore is num ? rawScore : num.tryParse('$rawScore');
    final announced = latest['is_announce_score_time_passed'];
    final graded =
        latest['score_at'] != null ||
        score != null ||
        latest['graded'] == true ||
        latest['is_graded'] == true;
    return HomeworkSubmissionState(
      submission: HomeworkSubmission.submitted,
      grading: announced == false
          ? HomeworkGrading.unpublished
          : graded
          ? HomeworkGrading.graded
          : announced == true ||
                latest['graded'] == false ||
                latest['is_graded'] == false
          ? HomeworkGrading.pending
          : HomeworkGrading.unknown,
      score: announced == false ? null : score,
    );
  }

  Map<String, dynamic> toJson() => {
    'submission': submission.name,
    'grading': grading.name,
    if (score != null) 'score': score,
  };
  factory HomeworkSubmissionState.fromJson(Map<String, dynamic> json) =>
      HomeworkSubmissionState(
        submission: HomeworkSubmission.values.firstWhere(
          (v) => v.name == json['submission'],
          orElse: () => HomeworkSubmission.unknown,
        ),
        grading: HomeworkGrading.values.firstWhere(
          (v) => v.name == json['grading'],
          orElse: () => HomeworkGrading.unknown,
        ),
        score: json['score'] is num ? json['score'] as num : null,
      );
}
