import 'package:dio/dio.dart';
import 'ta_models.dart';
import 'ta_repository.dart';

class TaGradeBatch {
  bool _stop = false;
  bool running = false;
  void stop() => _stop = true;

  Future<void> run({
    required TaGradingRepository repository,
    required int activityId,
    required List<TaGradeRow> rows,
    required bool overwrite,
    required bool allowUnsubmitted,
    required void Function() onChanged,
  }) async {
    if (running ||
        rows.any(
          (r) =>
              r.issue != null ||
              r.status == TaRowStatus.failed ||
              r.status == TaRowStatus.uncertain,
        )) {
      return;
    }
    running = true;
    _stop = false;
    onChanged();
    try {
      for (final row in rows) {
        if (_stop || !repository.active) break;
        // A second click may resume only rows that have never been sent.
        if (row.status != TaRowStatus.ready) continue;
        var writing = false;
        var acknowledged = false;
        try {
          final student = row.student!;
          if (!student.submitted && !allowUnsubmitted) {
            row.status = TaRowStatus.skipped;
            row.result = '未提交作业，已跳过';
            onChanged();
            continue;
          }
          final old = await repository.currentScore(activityId, student.id);
          if (_stop || !repository.active) break;
          if (old == double.parse(row.score) || old != null && !overwrite) {
            row.status = TaRowStatus.skipped;
            row.result = old == double.parse(row.score)
                ? '成绩相同，已跳过'
                : '已有成绩，未覆盖';
          } else {
            writing = true;
            await repository.saveScore(activityId, student.id, row.score);
            acknowledged = true;
            final saved = await repository.currentScore(activityId, student.id);
            if (saved != double.parse(row.score)) {
              throw const FormatException('保存后成绩待核对');
            }
            row.status = TaRowStatus.saved;
            row.result = '已保存并核对';
          }
          onChanged();
        } catch (error) {
          final rejected =
              error is DioException &&
              [
                400,
                401,
                403,
                404,
                422,
                429,
              ].contains(error.response?.statusCode);
          row.status = writing && (!rejected || acknowledged)
              ? TaRowStatus.uncertain
              : TaRowStatus.failed;
          row.result = row.status == TaRowStatus.uncertain
              ? '结果待确认，请查询后再决定是否重新导入'
              : '本行未完成，批次已停止，请检查权限与网络';
          onChanged();
          break;
        }
      }
    } finally {
      running = false;
      onChanged();
    }
  }
}
