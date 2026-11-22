import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/network/request_failure.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'ta_models.dart';

bool taIsMobile(BuildContext context) => switch (Theme.of(context).platform) {
  TargetPlatform.android || TargetPlatform.iOS => true,
  _ => false,
};

class TaTag extends StatelessWidget {
  const TaTag(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppPalette.of(context).muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone),
      ),
    );
  }
}

class TaOverview extends StatelessWidget {
  const TaOverview({
    super.key,
    required this.title,
    required this.total,
    required this.submitted,
    required this.graded,
    this.timeSummary,
  });
  final String title;
  final int total, submitted, graded;
  final String? timeSummary;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppGlassSurface(
      blur: 0,
      opacity: 1,
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTruncatedText(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (timeSummary != null && timeSummary!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                timeSummary!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: p.muted),
              ),
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              for (final metric in [
                ('应交', total),
                ('已提交', submitted),
                ('已批改', graded),
              ])
                Expanded(
                  child: AppMetric(value: '${metric.$2}', label: metric.$1),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '提交进度',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: p.muted),
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: total == 0 ? 0 : (submitted / total).clamp(0, 1),
              backgroundColor: p.primary.withValues(alpha: .1),
              color: p.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class TaStudentRow extends StatelessWidget {
  const TaStudentRow({
    super.key,
    required this.student,
    this.gradingKnown = false,
    this.showAvatar = false,
  });
  final TaStudent student;
  final bool gradingKnown;
  final bool showAvatar;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final score = student.score?.toString().replaceFirst(RegExp(r'\.0$'), '');
    final grade = score != null
        ? '$score 分'
        : student.scoreChecked || gradingKnown
        ? '未评分'
        : '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showAvatar) ...[
            AppIdentityAvatar(name: student.name, size: 36),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTruncatedText(
                  student.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  student.number,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: p.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (score != null)
            Text(
              grade,
              style: TextStyle(
                color: p.ink,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            AppStatusBadge(
              student.submitted ? '已提交' : '未提交',
              tone: student.submitted
                  ? AppStatusTone.success
                  : AppStatusTone.neutral,
              pill: true,
            ),
        ],
      ),
    );
  }
}

class TaFailureView extends StatelessWidget {
  const TaFailureView({super.key, required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          error is StateError && (error as StateError).message == '请先登录'
              ? '请先登录后查看助教课程'
              : error is FormatException
              ? (error as FormatException).message
              : requestFailureMessage(error),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: AppControlStyle.inlineOutlined(context),
          onPressed: retry,
          child: const Text('重试'),
        ),
      ],
    ),
  );
}
