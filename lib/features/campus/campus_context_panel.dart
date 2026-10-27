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
  });
  final VoidCallback onTimetable, onHomework;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = ref.watch(campusCachedDataProvider);
    final now =
        ref.watch(campusClockProvider).valueOrNull ??
        ref.read(campusNowProvider)();
    return CampusContextView(
      data: cached.valueOrNull ?? const CampusCachedData(),
      now: now,
      loading: cached.isLoading,
      onTimetable: onTimetable,
      onHomework: onHomework,
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
    this.loading = false,
  });
  final CampusCachedData data;
  final DateTime now;
  final VoidCallback onTimetable, onHomework;
  final bool loading;
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
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: p.ink,
            ),
          ),
        ),
        AppTextLink(action, onPressed: onTap),
      ],
    );
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
            if (summary.visible.isEmpty)
              Text(
                loading
                    ? '正在读取课程…'
                    : data.schedule == null
                    ? '尚未获取教务课表'
                    : '今天没有后续课程',
                style: TextStyle(color: p.muted, height: 1.7),
              ),
            if (summary.visible.isNotEmpty)
              Stack(
                children: [
                  Positioned(
                    left: 3.5,
                    top: 0,
                    bottom: 0,
                    width: 1,
                    child: ColoredBox(color: p.primary.withValues(alpha: .16)),
                  ),
                  Column(
                    children: [
                      for (final meeting in summary.visible)
                        _MeetingRow(
                          meeting: meeting,
                          current: identical(meeting, summary.current),
                        ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Divider(color: p.border, height: 1),
            const SizedBox(height: 24),
            heading('待办事项', '查看全部', onHomework),
            const SizedBox(height: 18),
            if (pending.isEmpty)
              Text(
                data.hasHomeworkCache ? '暂无待办事项' : '打开作业查看待办',
                style: TextStyle(color: p.muted, height: 1.7),
              )
            else
              InkWell(
                onTap: onHomework,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: p.isDark
                              ? p.selected
                              : const Color(0xFFE7F4FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          AppIcons.document,
                          color: p.isDark ? p.primary : const Color(0xFF1685D9),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pending.first.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: p.ink,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _due(pending.first),
                              style: TextStyle(
                                fontSize: 12,
                                color: p.muted,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (pending.length > 1)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onHomework,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('更多 ${pending.length - 1} 项'),
                      const SizedBox(width: 6),
                      const Icon(AppIcons.right, size: 16),
                    ],
                  ),
                ),
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
        : '${due.month}月${due.day}日';
    return '$date ${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')} ${due.isBefore(now) ? '已截止' : '截止'}';
  }
}

class _MeetingRow extends StatelessWidget {
  const _MeetingRow({required this.meeting, required this.current});
  final CampusMeeting meeting;
  final bool current;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    String hm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Padding(
      key: ValueKey('campus-meeting-${meeting.id}'),
      padding: EdgeInsets.only(bottom: current ? 10 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Icon(
              Icons.circle,
              size: 8,
              color: current ? p.primary : p.muted.withValues(alpha: .4),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              hm(meeting.start),
              style: TextStyle(
                fontSize: 12,
                color: current ? p.primary : p.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(10, current ? 8 : 2, 8, 10),
              decoration: BoxDecoration(
                color: current ? p.selected : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.6,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(AppIcons.location, size: 14, color: p.muted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          meeting.room.isEmpty ? '教室未提供' : meeting.room,
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${hm(meeting.start)}–${hm(meeting.end)}',
                    style: TextStyle(fontSize: 11, color: p.muted, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
