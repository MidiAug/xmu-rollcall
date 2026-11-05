import 'package:xmu_rollcall/app/chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/campus/campus_summary.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';

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
    this.mobile = false,
    this.showHomework = true,
  });
  final CampusCachedData data;
  final DateTime now;
  final VoidCallback onTimetable, onHomework;
  final ValueChanged<HomeworkItem> onOpenHomework;
  final bool loading;
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
              fontSize: mobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: mobile ? p.muted : p.ink,
            ),
          ),
        ),
        AppTextLink(action, onPressed: onTap),
      ],
    );
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading('今日课程', '查看课表', onTimetable),
          const SizedBox(height: 12),
          if (loading)
            const _CampusSummarySkeleton(course: true)
          else if (summary.visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                data.schedule == null ? '尚未获取教务课表' : '今天没有后续课程',
                style: TextStyle(color: p.muted, fontSize: 14),
              ),
            ),
          if (!loading)
            for (var i = 0; i < summary.visible.length; i++)
              _MobileMeetingRow(
                meeting: summary.visible[i],
                current: identical(summary.visible[i], summary.current),
                first: i == 0,
                last: i == summary.visible.length - 1,
              ),
          if (showHomework) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: p.border),
            const SizedBox(height: 12),
            heading('待办事项', '查看全部', onHomework),
            const SizedBox(height: 12),
            if (loading)
              const _CampusSummarySkeleton(course: false)
            else if (pending.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  data.hasHomeworkCache ? '暂无待办事项' : '打开作业查看待办',
                  style: TextStyle(color: p.muted, fontSize: 14),
                ),
              )
            else
              _MobileTodoRow(
                item: pending.first,
                deadline: _due(pending.first),
                onTap: () => onOpenHomework(pending.first),
              ),
          ],
        ],
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.content,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading('今日课程', '查看课表', onTimetable),
            const SizedBox(height: 12),
            if (loading)
              const _CampusSummarySkeleton(course: true)
            else if (summary.visible.isEmpty)
              Text(
                data.schedule == null ? '尚未获取教务课表' : '今天没有后续课程',
                style: TextStyle(color: p.muted, height: 1.7),
              ),
            if (!loading && summary.visible.isNotEmpty)
              Column(
                children: [
                  for (var i = 0; i < summary.visible.length; i++)
                    _MeetingRow(
                      meeting: summary.visible[i],
                      current: identical(summary.visible[i], summary.current),
                      first: i == 0,
                      last: i == summary.visible.length - 1,
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Divider(color: p.border, height: 1),
            const SizedBox(height: 24),
            heading('待办事项', '查看全部', onHomework),
            const SizedBox(height: 18),
            if (loading)
              const _CampusSummarySkeleton(course: false)
            else if (pending.isEmpty)
              Text(
                data.hasHomeworkCache ? '暂无待办事项' : '打开作业查看待办',
                style: TextStyle(color: p.muted, height: 1.7),
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
          borderRadius: BorderRadius.circular(10),
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

class _MobileMeetingRow extends StatelessWidget {
  const _MobileMeetingRow({
    required this.meeting,
    required this.current,
    required this.first,
    required this.last,
  });
  final CampusMeeting meeting;
  final bool current, first, last;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    String hm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    Widget meta(IconData icon, String text) => Row(
      children: [
        SizedBox(
          width: 16,
          height: MediaQuery.textScalerOf(context).scale(13) * 1.5,
          child: Center(child: Icon(icon, size: 15, color: p.muted)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.5, color: p.muted),
          ),
        ),
      ],
    );
    return IntrinsicHeight(
      key: ValueKey('campus-meeting-${meeting.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                hm(meeting.start),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: current ? p.primary : p.ink,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 16,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: CampusTimelinePainter(
                      first: first,
                      last: last,
                      color: p.primary.withValues(alpha: .18),
                    ),
                  ),
                ),
                Positioned(
                  top: 15,
                  left: 3,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: current ? p.primary : p.content,
                      border: Border.all(
                        color: current ? p.primary : p.muted,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: current
                      ? p.primary.withValues(alpha: .07)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    meta(
                      AppIcons.location,
                      meeting.room.isEmpty ? '教室未提供' : meeting.room,
                    ),
                    const SizedBox(height: 2),
                    meta(
                      AppIcons.clock,
                      '${hm(meeting.start)}–${hm(meeting.end)}',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    final blue = p.isDark ? const Color(0xFF79B8FF) : const Color(0xFF168AF0);
    final parts = deadline.split(' ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                key: const ValueKey('mobile-todo-mark'),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(AppIcons.todoDocument, size: 27, color: blue),
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
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: item.dueAt == null ? '' : '截止：${item.dueLabel}',
                child: SizedBox(
                  width:
                      64 *
                      MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.5),
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
        ),
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
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: p.hoverOverlay,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
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
                      color: p.isDark
                          ? const Color(0xFF163D57)
                          : const Color(0xFFE7F4FF),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      AppIcons.todoDocument,
                      size: 32,
                      color: p.isDark
                          ? const Color(0xFF70BEFF)
                          : const Color(0xFF087CE5),
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
        ),
      ),
    );
  }
}

class _MeetingRow extends StatelessWidget {
  const _MeetingRow({
    required this.meeting,
    required this.current,
    required this.first,
    required this.last,
  });
  final CampusMeeting meeting;
  final bool current, first, last;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    String hm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    Widget metadata(IconData icon, String label) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 14,
          height: MediaQuery.textScalerOf(context).scale(12) * 1.5,
          child: Center(child: Icon(icon, size: 14, color: p.muted)),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: p.muted, height: 1.5),
          ),
        ),
      ],
    );
    return IntrinsicHeight(
      key: ValueKey('campus-meeting-${meeting.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 14,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: CampusTimelinePainter(
                      first: first,
                      last: last,
                      color: p.primary.withValues(alpha: .3),
                    ),
                  ),
                ),
                Positioned(
                  top: 15,
                  left: 0,
                  child: Icon(
                    Icons.circle,
                    size: 14,
                    color: current ? p.primary : p.muted.withValues(alpha: .4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Text(
              hm(meeting.start),
              style: TextStyle(
                fontSize: 14,
                color: current ? p.primary : p.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
                decoration: BoxDecoration(
                  color: current ? p.selected : p.surface,
                  border: Border.all(
                    color: current
                        ? p.primary.withValues(alpha: .25)
                        : p.border,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.6,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    metadata(
                      AppIcons.location,
                      meeting.room.isEmpty ? '教室未提供' : meeting.room,
                    ),
                    const SizedBox(height: 6),
                    metadata(
                      AppIcons.clock,
                      '${hm(meeting.start)}–${hm(meeting.end)}',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Short tapered tails extend six pixels beyond the first/last card edge.
class CampusTimelinePainter extends CustomPainter {
  const CampusTimelinePainter({
    required this.first,
    required this.last,
    required this.color,
  });
  final bool first, last;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final top = first ? 2.0 : 0.0;
    final bottom = last ? size.height - 2 : size.height;
    final startWidth = first ? 0.5 : 1.5;
    final endWidth = last ? 0.5 : 1.5;
    final span = bottom - top;
    final path = Path()
      ..moveTo(x - startWidth, top)
      ..cubicTo(
        x - 1.5,
        top + span * .3,
        x - 1.5,
        bottom - span * .3,
        x - endWidth,
        bottom,
      )
      ..lineTo(x + endWidth, bottom)
      ..cubicTo(
        x + 1.5,
        bottom - span * .3,
        x + 1.5,
        top + span * .3,
        x + startWidth,
        top,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(CampusTimelinePainter old) =>
      first != old.first || last != old.last || color != old.color;
}
