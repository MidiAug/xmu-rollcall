import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
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
  var _scope = const CourseWatchScope();
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
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
      if (mounted) {
        setState(() {
          _scope = scope;
          _courses = courses;
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
      body: AppContentColumn(
        maxWidth: 1040,
        child: Theme(
          data: Theme.of(context).copyWith(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            hoverColor: p.hover.withValues(alpha: p.hover.a * .45),
            checkboxTheme: CheckboxThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? p.primary.withValues(alpha: .12)
                    : Colors.transparent,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, bounds) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  '只照看你需要的课',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '默认包含全部课程。关闭整门课程，或只取消每周某一次上课安排；修改自动保存。',
                  style: TextStyle(color: p.muted, height: 1.6),
                ),
                const SizedBox(height: 20),
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
                if (bounds.maxWidth >= 728)
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
      ),
    );
  }

  Widget _courseCard(CatalogCourse course, AppPalette p) => Material(
    key: ValueKey('watch-course-card-${course.id}'),
    color: p.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: p.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        CheckboxListTile(
          key: ValueKey('watch-course-${course.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          tristate: true,
          value: _scope.selectionFor(course),
          title: Text(
            course.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              color: p.ink,
            ),
          ),
          subtitle: Text(
            course.needsSchedule
                ? '暂无可用的上课安排'
                : _scope.excludedCourses.contains(course.id)
                ? '本课程不参与值守'
                : '勾选的上课安排参与值守',
            style: AppTypography.caption.copyWith(color: p.muted),
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
            for (final block in courseWatchWeeklyBlocks(
              course.timetables[day]!,
            ))
              CheckboxListTile(
                key: ValueKey(
                  'watch-meeting-${CourseWatchScope.meetingKey(course.id, day, block.id)}',
                ),
                contentPadding: const EdgeInsets.only(left: 32, right: 16),
                dense: true,
                value: _scope.allows(course.id, day, block.id),
                title: Text(
                  '每${weekdayLabel(day)}  ${block.sectionLabel}',
                  style: AppTypography.control.copyWith(color: p.ink),
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
    ),
  );
}
