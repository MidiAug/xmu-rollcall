import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
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
    final tone = color ?? AppPalette.of(context).primary;
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
    required this.caption,
    required this.total,
    required this.submitted,
    required this.graded,
  });
  final String title, caption;
  final int total, submitted, graded;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.accentSurface.withValues(alpha: p.isDark ? .6 : .65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.primary.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: p.primary),
          ),
          const SizedBox(height: 9),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 22),
          Row(
            children: [
              for (final metric in [
                ('应交', total),
                ('已提交', submitted),
                ('已批改', graded),
              ])
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${metric.$2}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        metric.$1,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: p.muted),
                      ),
                    ],
                  ),
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
    required this.onCheck,
    this.selected,
    this.onSelected,
    this.checking = false,
    this.gradingKnown = false,
  });
  final TaStudent student;
  final VoidCallback? onCheck;
  final bool? selected;
  final ValueChanged<bool?>? onSelected;
  final bool checking, gradingKnown;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final score = student.score?.toString().replaceFirst(RegExp(r'\.0$'), '');
    final grade = score != null
        ? '$score 分'
        : student.scoreChecked || gradingKnown
        ? '未批改'
        : '待核对';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (selected != null)
            Checkbox(value: selected, onChanged: onSelected)
          else
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: p.controlSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.person_outline, size: 18, color: p.muted),
            ),
          const SizedBox(width: 8),
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
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    TaTag(
                      student.submitted ? '已提交' : '未提交',
                      color: student.submitted ? p.success : p.muted,
                    ),
                    TaTag(grade, color: score != null ? p.primary : p.muted),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: checking ? '正在核对' : '核对成绩',
            onPressed: onCheck,
            icon: checking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}
