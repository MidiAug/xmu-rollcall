import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_overview.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

class HomeworkStatusBadges extends ConsumerWidget {
  const HomeworkStatusBadges({
    super.key,
    required this.item,
    this.withDeadline = false,
  });
  final HomeworkItem item;
  final bool withDeadline;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teaching = ref.watch(currentTeachingCoursesProvider);
    if (!teaching.hasValue ||
        teaching.requireValue.any((c) => c.id == '${item.courseId}')) {
      return withDeadline
          ? _HomeworkMetadataRow(item: item)
          : const SizedBox.shrink();
    }
    if (!item.isHomework) {
      return withDeadline
          ? _HomeworkMetadataRow(item: item)
          : const SizedBox.shrink();
    }
    final uid =
        ref.watch(selectedRollcallAccountProvider) ??
        ref.watch(authControllerProvider).profile?.id;
    if (uid == null || item.id <= 0) return const SizedBox.shrink();
    final async = ref.watch(
      homeworkSubmissionProvider(
        HomeworkStatusKey(
          uid,
          item.id,
          closed: item.isOverdue,
          dueAt: item.dueAt,
        ),
      ),
    );
    final p = AppPalette.of(context);
    final state = async.valueOrNull;
    if (withDeadline) {
      return _HomeworkMetadataRow(
        item: item,
        state: state,
        placeholder: async.isLoading ? '读取中' : '未知',
      );
    }
    if (state == null) {
      return Text(
        async.isLoading ? '读取状态…' : '状态暂不可用',
        style: TextStyle(fontSize: 11, color: p.muted),
      );
    }
    Widget chip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, height: 1.3, color: color),
      ),
    );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        chip(
          state.submissionLabel,
          state.submission == HomeworkSubmission.submitted
              ? p.primary
              : item.isOverdue
              ? p.danger
              : p.muted,
        ),
        if (state.gradingLabel != null) chip(state.gradingLabel!, p.muted),
      ],
    );
  }
}

/// Stable first two columns; the last badge keeps its natural width.
class _HomeworkMetadataRow extends StatelessWidget {
  const _HomeworkMetadataRow({
    required this.item,
    this.state,
    this.placeholder,
  });
  final HomeworkItem item;
  final HomeworkSubmissionState? state;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final due = item.dueAt?.toLocal();
    final timeStyle = TextStyle(
      fontSize: 11,
      height: 1.3,
      color: p.muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final deadline = due == null
        ? '无截止日期'
        : '${due.month.toString().padLeft(2, '0')}/'
              '${due.day.toString().padLeft(2, '0')} '
              '${due.hour.toString().padLeft(2, '0')}:'
              '${due.minute.toString().padLeft(2, '0')}';
    Widget badge(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Text(
        label,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, height: 1.3, color: color),
      ),
    );
    final submission = switch (state?.submission) {
      HomeworkSubmission.draft => '草稿',
      HomeworkSubmission.unknown => '未知',
      _ => state?.submissionLabel ?? placeholder,
    };
    final grading = state?.gradingLabel;
    final submissionColor = state?.submission == HomeworkSubmission.submitted
        ? p.primary
        : item.isOverdue &&
              (state?.submission == HomeworkSubmission.unsubmitted ||
                  state?.submission == HomeworkSubmission.draft)
        ? p.danger
        : p.muted;
    double textWidth(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width.ceilToDouble();
      painter.dispose();
      return width;
    }

    final timeWidth = textWidth('00/00 00:00', timeStyle);
    final statusWidth = textWidth('未提交', const TextStyle(fontSize: 11)) + 14;
    return Row(
      children: [
        SizedBox(
          key: ValueKey('homework-deadline-${item.id}'),
          width: timeWidth,
          child: Tooltip(
            message: '截止时间 ${item.dueLabel}',
            child: Semantics(
              label: '截止时间 ${item.dueLabel}',
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(deadline, style: timeStyle),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          key: ValueKey('homework-submission-${item.id}'),
          width: statusWidth,
          child: submission == null
              ? const SizedBox.shrink()
              : Tooltip(
                  message: state?.submissionLabel ?? submission,
                  child: badge(submission, submissionColor),
                ),
        ),
        const SizedBox(width: 6),
        if (grading != null)
          Flexible(
            child: FittedBox(
              key: ValueKey('homework-grading-${item.id}'),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: badge(grading, p.muted),
            ),
          ),
      ],
    );
  }
}
