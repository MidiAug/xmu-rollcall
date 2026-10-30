import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_switch.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'course_watch.dart';
import 'course_watch_courses_page.dart';
import 'monitor_controller.dart';

class CourseWatchSettings extends ConsumerStatefulWidget {
  const CourseWatchSettings({
    super.key,
    required this.ownerId,
    required this.targetId,
  });
  final int ownerId, targetId;
  @override
  ConsumerState<CourseWatchSettings> createState() =>
      _CourseWatchSettingsState();
}

class _CourseWatchSettingsState extends ConsumerState<CourseWatchSettings> {
  CourseWatchScope _scope = const CourseWatchScope();
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
      if (mounted) {
        setState(() {
          _scope = scope;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '课程范围读取失败，请重新打开此页');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final state = ref.watch(monitorControllerProvider);
    final ctrl = ref.read(monitorControllerProvider.notifier);
    final c = state.config;
    final ready = widget.ownerId != 0 && !state.loadingSettings;
    final status = !c.courseWatch
        ? '未启用'
        : state.starting
        ? '正在启动'
        : !state.running
        ? '已暂停'
        : state.waitingForWindow
        ? '等待下个检测时段'
        : !state.discovering
        ? '正在处理签到'
        : '正在检测';
    final scopeText =
        _error ??
        (_scope.excludedCourses.isEmpty && _scope.excludedMeetings.isEmpty
            ? '全部课程与上课安排'
            : '已排除 ${_scope.excludedCourses.length} 门课程、${_scope.excludedMeetings.length} 个安排');
    final next = state.nextPollAt?.toLocal();
    Widget phase(String title, String time, {bool compact = false}) =>
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: p.content,
            borderRadius: BorderRadius.circular(12),
          ),
          child: compact
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(color: p.muted, fontSize: 12),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: p.muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(
                      time,
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: p.accentSurface,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(AppIcons.detect, color: p.primary, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '课表值守',
                          style: TextStyle(
                            color: p.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status,
                          style: TextStyle(
                            color: state.running ? p.primary : p.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSwitch(
                    key: const ValueKey('monitor-course-watch'),
                    value: c.courseWatch,
                    onChanged: ready && !state.running && !state.starting
                        ? ctrl.setCourseWatch
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, bounds) {
                  if (bounds.maxWidth < 360) {
                    return Column(
                      children: [
                        phase('课前', '10 分钟', compact: true),
                        const SizedBox(height: 6),
                        phase('每次课间', '按课表时间', compact: true),
                        const SizedBox(height: 6),
                        phase('课后', '10 分钟', compact: true),
                      ],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: phase('课前', '10 分钟')),
                        const SizedBox(width: 8),
                        Expanded(child: phase('每次课间', '按课表时间')),
                        const SizedBox(width: 8),
                        Expanded(child: phase('课后', '10 分钟')),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                '从上一小节下课检测到下一小节上课，长课间也完整覆盖，无需额外设置。',
                style: TextStyle(color: p.muted, fontSize: 12, height: 1.5),
              ),
              if (c.courseWatch) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.running && state.waitingForWindow && next != null
                            ? '下次检测 ${next.month}月${next.day}日 ${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}'
                            : c.autoAnswer
                            ? '发现签到后按你的设置自动提交'
                            : '当前仅提醒，开启下方“自动签到”后可自动提交',
                        style: TextStyle(
                          color: p.muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      key: const ValueKey('course-watch-run'),
                      onPressed: !ready || state.starting
                          ? null
                          : () async {
                              if (state.running) {
                                ctrl.stop();
                                return;
                              }
                              final result = await ctrl.startAsync();
                              if (context.mounted &&
                                  result != StartMonitorResult.started &&
                                  result != StartMonitorResult.alreadyRunning) {
                                AppToast.show(
                                  context,
                                  '值守未能启动，请检查登录与检测记录',
                                  error: true,
                                );
                              }
                            },
                      icon: Icon(
                        state.running ? AppIcons.stop : AppIcons.detect,
                        size: 16,
                      ),
                      label: Text(state.running ? '暂停值守' : '开始值守'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (c.courseWatch) ...[
          const SizedBox(height: 18),
          SettingsSection(
            padTop: false,
            header: '值守范围',
            hasLeading: false,
            children: [
              SettingsRow(
                title: '值守课程',
                subtitle: state.running ? '暂停值守后可调整课程范围' : scopeText,
                onTap: ready && !state.running && !state.starting
                    ? () async {
                        await AppPageRoutes.push(
                          context,
                          CourseWatchCoursesPage(
                            ownerId: widget.ownerId,
                            targetId: widget.targetId,
                          ),
                        );
                        if (mounted) await _load();
                      }
                    : null,
                trailing: Icon(AppIcons.right, color: p.muted, size: 18),
              ),
              SettingsRow(
                title: '完整探查',
                subtitle: c.completeProbe
                    ? '已签到后仍检查后续课间与课后'
                    : '成功签到一次后，本次课不再探查',
                stackSubtitleOnNarrow: true,
                trailing: AppSwitch(
                  key: const ValueKey('monitor-complete-probe'),
                  value: c.completeProbe,
                  onChanged: ready ? ctrl.setCompleteProbe : null,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
