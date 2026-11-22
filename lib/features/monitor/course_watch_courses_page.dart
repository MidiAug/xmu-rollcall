import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/features/history/history_summary.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'course_watch.dart';

class CourseWatchCoursesPage extends StatefulWidget {
  const CourseWatchCoursesPage({
    super.key,
    required this.ownerId,
    required this.targetId,
  });
  final int ownerId, targetId;
  @override
  State<CourseWatchCoursesPage> createState() => _CourseWatchCoursesPageState();
}

class _CourseWatchCoursesPageState extends State<CourseWatchCoursesPage> {
  List<CatalogCourse>? _courses;
  Map<String, ({CourseRollcallTypeCounts counts, bool partial})?>? _types;
  var _scope = const CourseWatchScope();
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void reassemble() {
    super.reassemble();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scope = CourseWatchScope.fromPrefs(
        prefs,
        widget.ownerId,
        widget.targetId,
      );
      final courses = await readCourseWatchCourses(widget.targetId);
      final types =
          <String, ({CourseRollcallTypeCounts counts, bool partial})?>{};
      for (final course in courses) {
        final history = await CourseRollcallsStore.read(
          widget.targetId,
          course.id,
        );
        types[course.id] =
            history?.lastSuccessfulFetch == null &&
                (history?.records.isEmpty ?? true)
            ? null
            : (
                counts: CourseRollcallTypeCounts.fromRecords(history!.records),
                partial: history.truncated,
              );
      }
      if (mounted) {
        setState(() {
          _scope = scope;
          _courses = courses;
          _types = types;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '课程范围读取失败，请重试');
    }
  }

  Future<void> _save(CourseWatchScope next) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await next.save(widget.ownerId, widget.targetId);
      if (mounted) setState(() => _scope = next);
    } catch (_) {
      if (mounted) setState(() => _error = '课程范围未能保存，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SubpageScaffold(
      title: '值守课程',
      body: AppPageViewport(
        maxWidth: AppLayout.workspaceMaxWidth,
        builder: (context, contentInsets) => LayoutBuilder(
          builder: (context, bounds) => ListView(
            padding: contentInsets + EdgeInsets.all(AppSpace.pageXOf(context)),
            children: [
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: p.danger)),
                TextButton(onPressed: _load, child: const Text('重新读取')),
              ],
              if (_courses == null && _error == null)
                const Center(child: CircularProgressIndicator()),
              if (_courses?.isEmpty == true)
                Text(
                  '暂无可关联的课程，请先获取课表并查看一次畅课课程。',
                  style: TextStyle(color: p.muted),
                ),
              if (_courses?.isNotEmpty == true) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '已选 ${_courses!.where((course) => _scope.selectionFor(course) != false).length} 门参与课表值守',
                    style: AppTypography.body.copyWith(color: p.muted),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (bounds.maxWidth - contentInsets.horizontal >= 728)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var column = 0; column < 2; column++) ...[
                      if (column != 0) const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            for (
                              var i = column;
                              i < (_courses?.length ?? 0);
                              i += 2
                            ) ...[
                              _courseCard(_courses![i], p),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                )
              else
                for (final course in _courses ?? <CatalogCourse>[]) ...[
                  _courseCard(course, p),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _courseCard(CatalogCourse course, AppPalette p) => SettingsSection(
    key: ValueKey('watch-course-card-${course.id}'),
    padTop: false,
    hasLeading: false,
    children: [
      AppCheckboxRow(
        key: ValueKey('watch-course-${course.id}'),
        label: course.title,
        trailing: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        value: _scope.selectionFor(course),
        title: AppTruncatedText(
          course.title,
          style: AppTypography.body.copyWith(
            fontSize: AppDensity.isTouch(context) ? 17 : 15,
            fontWeight: FontWeight.w600,
            color: _scope.excludedCourses.contains(course.id) ? p.muted : p.ink,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (course.needsSchedule ||
                _scope.excludedCourses.contains(course.id)) ...[
              Text(
                course.needsSchedule ? '暂无可用的上课安排' : '本课程不参与值守',
                style: AppTypography.caption.copyWith(color: p.muted),
              ),
              const SizedBox(height: 6),
            ],
            _historyTypes(course.id, p),
          ],
        ),
        onChanged: _saving
            ? null
            : (included) {
                final excluded = {..._scope.excludedCourses};
                final meetings = {..._scope.excludedMeetings};
                if (_scope.excludedCourses.contains(course.id)) {
                  excluded.remove(course.id);
                } else if (_scope.selectionFor(course) == false) {
                  for (final day in course.timetables.entries) {
                    for (final block in courseWatchWeeklyBlocks(day.value)) {
                      meetings.remove(
                        CourseWatchScope.meetingKey(
                          course.id,
                          day.key,
                          block.id,
                        ),
                      );
                    }
                  }
                } else {
                  excluded.add(course.id);
                }
                _save(
                  CourseWatchScope(
                    excludedCourses: excluded,
                    excludedMeetings: meetings,
                  ),
                );
              },
      ),
      if (!_scope.excludedCourses.contains(course.id))
        for (final day in course.timetables.keys.toList()..sort())
          for (final block in courseWatchWeeklyBlocks(course.timetables[day]!))
            AppCheckboxRow(
              key: ValueKey(
                'watch-meeting-${CourseWatchScope.meetingKey(course.id, day, block.id)}',
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              trailing: true,
              label: '每${weekdayLabel(day)}  ${block.sectionLabel}',
              value: _scope.allows(course.id, day, block.id),
              title: Text(
                '每${weekdayLabel(day)}  ${block.sectionLabel}',
                style: AppTypography.body.copyWith(
                  fontSize: AppDensity.isTouch(context) ? 17 : 15,
                  fontWeight: FontWeight.w500,
                  color: p.ink,
                ),
              ),
              subtitle: Text(
                '${formatHm(block.coreStart)} – ${formatHm(block.coreEnd)}',
                style: AppTypography.caption.copyWith(color: p.muted),
              ),
              onChanged: _saving
                  ? null
                  : (included) {
                      final excluded = {..._scope.excludedMeetings};
                      final key = CourseWatchScope.meetingKey(
                        course.id,
                        day,
                        block.id,
                      );
                      if (included == true) {
                        excluded.remove(key);
                      } else {
                        excluded.add(key);
                      }
                      _save(
                        CourseWatchScope(
                          excludedCourses: _scope.excludedCourses,
                          excludedMeetings: excluded,
                        ),
                      );
                    },
            ),
    ],
  );

  Widget _historyTypes(String courseId, AppPalette p) {
    final history = _types?[courseId];
    final counts = history?.counts;
    final style = AppTypography.caption.copyWith(color: p.muted);
    if (counts == null) return Text('尚无历史缓存', style: style);
    if (counts.total == 0) return Text('缓存历史：暂无签到记录', style: style);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(history!.partial ? '缓存历史（部分）' : '缓存历史', style: style),
        for (final entry in [
          ('数字', counts.number),
          ('雷达', counts.radar),
          ('二维码', counts.qr),
          if (counts.other > 0) ('其他', counts.other),
        ])
          Text('${entry.$1} ${entry.$2}', style: style),
      ],
    );
  }
}
