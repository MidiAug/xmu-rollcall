import 'package:xmu_rollcall/app/chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/campus/campus_summary.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';

class CampusContextPanel extends ConsumerWidget {
  const CampusContextPanel({
    super.key,
    required this.onTimetable,
    required this.onHomework,
    required this.onOpenHomework,
  });
  final VoidCallback onTimetable, onHomework;
  final ValueChanged<HomeworkItem> onOpenHomework;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final scope = ref.watch(selectedRollcallAccountProvider);
    final uid = scope ?? auth.profile?.id;
    final scheduleSyncing =
        auth.isSignedIn &&
        uid != null &&
        ref.watch(academicSyncingUidsProvider.select((s) => s.contains(uid)));
    final cached = ref.watch(campusCachedDataProvider);
    final now =
        ref.watch(campusClockProvider).valueOrNull ??
        ref.read(campusNowProvider)();
    return CampusContextView(
      data:
          (cached.isLoading ? null : cached.valueOrNull) ??
          const CampusCachedData(),
      now: now,
      loading: cached.isLoading,
      scheduleSyncing: scheduleSyncing,
      onTimetable: onTimetable,
      onHomework: onHomework,
      onOpenHomework: onOpenHomework,
    );
  }
}

/// Pure view with explicit data and actions, suitable for previews and widgets.
class CampusContextView extends StatelessWidget {
  const CampusContextView({
    super.key,
    required this.data,
    required this.now,
    required this.onTimetable,
    required this.onHomework,
    required this.onOpenHomework,
    this.loading = false,
    this.scheduleSyncing = false,
    this.mobile = false,
    this.showHomework = true,
  });
  final CampusCachedData data;
  final DateTime now;
  final VoidCallback onTimetable, onHomework;
  final ValueChanged<HomeworkItem> onOpenHomework;
  final bool loading;
  final bool scheduleSyncing;
  final bool mobile;
  final bool showHomework;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final summary = data.schedule == null
        ? const CampusCourseSummary()
        : selectCampusCourses(data.schedule!, now);
    final pending = [...data.homework]
      ..sort((a, b) {
        final aDue = a.dueAt, bDue = b.dueAt;
        if (aDue == null) return bDue == null ? a.id.compareTo(b.id) : 1;
        if (bDue == null) return -1;
        final cmp = aDue.compareTo(bDue);
        return cmp != 0 ? cmp : a.id.compareTo(b.id);
      });
    Widget heading(String title, String action, VoidCallback onTap) => Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: mobile ? 17 : 16,
              fontWeight: FontWeight.w600,
              color: p.ink,
            ),
          ),
        ),
        AppTextLink(action, onPressed: onTap),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          lifted: true,
          outlined: true,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading('今日课程', '查看课表', onTimetable),
              const SizedBox(height: 20),
              if (loading)
                const _CampusSummarySkeleton(course: true)
              else if (summary.visible.isEmpty)
                Text(
                  data.schedule == null
                      ? (scheduleSyncing ? '正在更新课表…' : '尚未获取教务课表')
                      : '今天没有后续课程',
                  style: AppTypography.body.copyWith(color: p.muted),
                )
              else
                for (var i = 0; i < summary.visible.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(78, 16, 0, 16),
                      child: Divider(height: 1, color: p.divider),
                    ),
                  _MeetingRow(
                    meeting: summary.visible[i],
                    current: identical(summary.visible[i], summary.current),
                  ),
                ],
            ],
          ),
        ),
        if (showHomework) ...[
          const SizedBox(height: 20),
          Panel(
            lifted: true,
            outlined: true,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading('待办事项', '查看全部', onHomework),
                const SizedBox(height: 18),
                if (loading)
                  const _CampusSummarySkeleton(course: false)
                else if (pending.isEmpty)
                  Text(
                    data.hasHomeworkCache ? '暂无待办事项' : '打开作业查看待办',
                    style: AppTypography.body.copyWith(color: p.muted),
                  )
                else if (mobile)
                  _MobileTodoRow(
                    item: pending.first,
                    deadline: _due(pending.first),
                    onTap: () => onOpenHomework(pending.first),
                  )
                else
                  _TodoPreview(
                    item: pending.first,
                    deadline: _due(pending.first),
                    overdue: pending.first.dueAt?.isBefore(now) == true,
                    onTap: () => onOpenHomework(pending.first),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _due(HomeworkItem item) {
    final due = item.dueAt?.toLocal();
    if (due == null) return '无截止日期';
    final day = DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final date = day == 0
        ? '今天'
        : day == 1
        ? '明天'
        : '${due.month}/${due.day}';
    if (due.isBefore(now)) return '已截止';
    return '$date ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}';
  }
}

/// Static placeholders keep both sections visible without adding a polling ticker.
class _CampusSummarySkeleton extends StatelessWidget {
  const _CampusSummarySkeleton({required this.course});
  final bool course;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget line(double fraction, double height) => FractionallySizedBox(
      widthFactor: fraction,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: p.muted.withValues(alpha: p.isDark ? .18 : .12),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
    return Semantics(
      label: course ? '正在读取今日课程' : '正在读取待办事项',
      child: Container(
        key: ValueKey(
          course ? 'campus-course-skeleton' : 'campus-homework-skeleton',
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: p.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line(.78, 14),
            const SizedBox(height: 12),
            line(.58, 10),
            if (course) ...[const SizedBox(height: 8), line(.68, 10)],
          ],
        ),
      ),
    );
  }
}

class _MobileTodoRow extends StatelessWidget {
  const _MobileTodoRow({
    required this.item,
    required this.deadline,
    required this.onTap,
  });
  final HomeworkItem item;
  final String deadline;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final parts = deadline.split(' ');
    return AppHoverSurface(
      outlined: false,
      backgroundColor: Colors.transparent,
      hoverColor: p.cardHover,
      pressedColor: p.hover,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.symmetric(vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            key: const ValueKey('mobile-todo-mark'),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.documentSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              AppIcons.todoDocument,
              size: 27,
              color: p.documentAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTruncatedText(
                  item.courseName.trim().isEmpty ? '课程作业' : item.courseName,
                  key: const ValueKey('todo-course-name'),
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                AppTruncatedText(
                  item.title,
                  key: const ValueKey('mobile-todo-title'),
                  style: TextStyle(fontSize: 13, height: 1.5, color: p.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: item.dueAt == null ? '' : '截止：${item.dueLabel}',
            child: SizedBox(
              width:
                  64 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.5),
              child: Column(
                key: const ValueKey('todo-deadline'),
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    parts.first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: deadline == '已截止' ? p.warning : p.ink,
                    ),
                  ),
                  if (parts.length > 1) ...[
                    const SizedBox(height: 3),
                    Text(
                      parts.last,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: p.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two visual levels: course/deadline metadata, then the assignment itself.
class _TodoPreview extends StatelessWidget {
  const _TodoPreview({
    required this.item,
    required this.deadline,
    required this.overdue,
    required this.onTap,
  });
  final HomeworkItem item;
  final String deadline;
  final bool overdue;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppHoverSurface(
      backgroundColor: p.surface,
      hoverColor: p.cardHover,
      pressedColor: p.hover,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.courseName.trim().isEmpty ? '课程作业' : item.courseName,
                  key: const ValueKey('todo-course-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: p.muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: const ValueKey('todo-deadline'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: overdue
                      ? p.danger.withValues(alpha: .08)
                      : p.surfaceHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.clock,
                      size: 12,
                      color: overdue ? p.danger : p.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      deadline,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: overdue ? p.danger : p.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                key: const ValueKey('todo-document-mark'),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: p.documentSurface,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  AppIcons.todoDocument,
                  size: 32,
                  color: p.documentAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  key: const ValueKey('todo-homework-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeetingRow extends StatelessWidget {
  const _MeetingRow({required this.meeting, required this.current});
  final CampusMeeting meeting;
  final bool current;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    String hm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Row(
      key: ValueKey('campus-meeting-${meeting.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48 * scale,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hm(meeting.start),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: current ? p.primary : p.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hm(meeting.end),
                style: TextStyle(fontSize: 12, height: 1.5, color: p.subtle),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            key: ValueKey('campus-meeting-bar-${meeting.id}'),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  width: current ? 2 : 1,
                  color: current ? p.primary : p.divider,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTruncatedText(
                  meeting.title,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  meeting.room.isEmpty ? '教室未提供' : meeting.room,
                  style: AppTypography.body.copyWith(color: p.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
