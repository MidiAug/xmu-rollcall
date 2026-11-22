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

class TaAssignmentCountChips extends StatelessWidget {
  const TaAssignmentCountChips({super.key, required this.assignment});
  final TaAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final baseStyle = Theme.of(context).textTheme.bodySmall ?? const TextStyle();
    final metrics = [
      (
        '应交',
        assignment.expected,
        p.pillMuted,
        p.surfaceRim,
        p.muted,
        FontWeight.w500,
      ),
      (
        '已提交',
        assignment.submitted,
        assignment.submitted > 0 ? p.controlSurface : p.pillMuted,
        assignment.submitted > 0 ? p.controlRim : p.surfaceRim,
        assignment.submitted > 0 ? p.inkBody : p.muted,
        assignment.submitted > 0 ? FontWeight.w600 : FontWeight.w500,
      ),
      (
        '已批改',
        assignment.graded,
        assignment.submitted > 0 && assignment.graded >= assignment.submitted
            ? p.successSurface
            : assignment.graded > 0
            ? p.controlSurface
            : p.pillMuted,
        assignment.submitted > 0 && assignment.graded >= assignment.submitted
            ? p.successRim
            : assignment.graded > 0
            ? p.controlRim
            : p.surfaceRim,
        assignment.submitted > 0 && assignment.graded >= assignment.submitted
            ? p.success
            : assignment.graded > 0
            ? p.inkBody
            : p.muted,
        assignment.graded > 0 ||
                (assignment.submitted > 0 &&
                    assignment.graded >= assignment.submitted)
            ? FontWeight.w600
            : FontWeight.w500,
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final metric in metrics)
          Container(
            constraints: BoxConstraints(
              minWidth: (metric.$1 == '应交' ? 68.0 : 80.0) * scale,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: metric.$3,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: metric.$4),
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                '${metric.$1} ${metric.$2}',
                maxLines: 1,
                softWrap: false,
                style: baseStyle.copyWith(
                  fontSize: 12,
                  height: 1.2,
                  color: metric.$5,
                  fontWeight: metric.$6,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class TaAssignmentTimeColumn extends StatelessWidget {
  const TaAssignmentTimeColumn({super.key, required this.assignment});
  final TaAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final baseStyle = Theme.of(context).textTheme.bodySmall ?? const TextStyle();
    final times = assignment.timeMetrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < times.length; i++) ...[
          if (i > 0) const SizedBox(height: 3),
          Text(
            '${times[i].$1} ${times[i].$2}',
            maxLines: 1,
            softWrap: false,
            style: baseStyle.copyWith(
              color: times[i].$1 == '开放' ? p.subtle : p.muted,
              fontSize: 12,
              height: 1.3,
              fontWeight: times[i].$1 == '开放' ? null : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

class TaAssignmentTimeRow extends StatelessWidget {
  const TaAssignmentTimeRow({super.key, required this.assignment});
  final TaAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final baseStyle = Theme.of(context).textTheme.bodySmall ?? const TextStyle();
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final time in assignment.timeMetrics)
          Text(
            '${time.$1} ${time.$2}',
            maxLines: 1,
            softWrap: false,
            style: baseStyle.copyWith(
              color: time.$1 == '开放' ? p.muted : p.inkBody,
              fontSize: 12,
              height: 1.3,
              fontWeight: time.$1 == '开放' ? null : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

class TaAssignmentSummaryBar extends StatelessWidget {
  const TaAssignmentSummaryBar({super.key, required this.assignment});
  final TaAssignment assignment;

  @override
  Widget build(BuildContext context) {
    if (assignment.timeMetrics.isEmpty) {
      return TaAssignmentCountChips(assignment: assignment);
    }
    final p = AppPalette.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, bounds) {
        if (bounds.maxWidth >= 480 * scale) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TaAssignmentCountChips(assignment: assignment),
              const SizedBox(width: 12),
              Container(width: 1, height: 14, color: p.borderStrong),
              const SizedBox(width: 12),
              Flexible(child: TaAssignmentTimeRow(assignment: assignment)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TaAssignmentCountChips(assignment: assignment),
            const SizedBox(height: 6),
            TaAssignmentTimeRow(assignment: assignment),
          ],
        );
      },
    );
  }
}

class TaStudentRow extends StatelessWidget {
  const TaStudentRow({
    super.key,
    required this.student,
    this.gradingKnown = false,
    this.showAvatar = false,
    this.isFirst = false,
    this.isLast = false,
  });
  final TaStudent student;
  final bool gradingKnown;
  final bool showAvatar;
  final bool isFirst;
  final bool isLast;
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
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(AppRadii.card) : Radius.zero,
          bottom: isLast ? const Radius.circular(AppRadii.card) : Radius.zero,
        ),
        border: Border(
          top: isFirst ? BorderSide(color: p.surfaceRim) : BorderSide.none,
          left: BorderSide(color: p.surfaceRim),
          right: BorderSide(color: p.surfaceRim),
          bottom: isLast ? BorderSide(color: p.surfaceRim) : BorderSide.none,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
          ),
          if (!isLast)
            Divider(height: 1, thickness: 1, indent: 1, endIndent: 1, color: p.divider),
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
