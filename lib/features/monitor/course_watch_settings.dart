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
        ? '未运行'
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
    Widget phase(String title, String time) => SizedBox(
      width: 180 * MediaQuery.textScalerOf(context).scale(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.caption.copyWith(color: p.muted)),
          const SizedBox(height: 4),
          Text(time, style: AppTypography.body.copyWith(color: p.ink)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          padTop: false,
          hasLeading: false,
          children: [
            SettingsRow(
              title: '课表值守',
              subtitle: '在上课、课间和下课前后的时段检测签到',
              stackSubtitleOnNarrow: true,
              trailing: AppSwitch(
                key: const ValueKey('monitor-course-watch'),
                value: c.courseWatch,
                onChanged: !ready
                    ? null
                    : (value) {
                        if (state.running || state.starting) {
                          AppToast.show(
                            context,
                            state.starting
                                ? '值守正在启动，请稍候再调整'
                                : '请先暂停值守，再调整课表值守设置',
                          );
                          return;
                        }
                        ctrl.setCourseWatch(value);
                      },
              ),
            ),
            if (c.courseWatch)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    phase('上课', '前 10 至后 5 分钟'),
                    phase('课间', '前后各延 2.5 分钟'),
                    phase('下课', '前 5 至后 10 分钟'),
                  ],
                ),
              ),
            if (c.courseWatch)
              SettingsRow(
                title: status,
                subtitle:
                    state.running && state.waitingForWindow && next != null
                    ? '下次检测 ${next.month}月${next.day}日 ${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}'
                    : c.autoAnswer
                    ? '发现签到后按你的设置自动提交'
                    : '当前仅提醒，开启下方“自动签到”后可自动提交',
                stackSubtitleOnNarrow: true,
                trailing: OutlinedButton.icon(
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
                    state.running ? AppIcons.pause : AppIcons.play,
                    size: 16,
                  ),
                  label: Text(state.running ? '暂停值守' : '开始值守'),
                ),
              ),
          ],
        ),
        if (c.courseWatch) ...[
          const SizedBox(height: AppSpace.xl),
          SettingsSection(
            padTop: false,
            header: '值守范围',
            hasLeading: false,
            children: [
              SettingsRow(
                title: '值守课程',
                subtitle: state.running ? '暂停值守后可调整课程范围' : scopeText,
                onTap: ready
                    ? () async {
                        if (state.running || state.starting) {
                          AppToast.show(
                            context,
                            state.starting ? '值守正在启动，请稍候再调整' : '请先暂停值守，再调整值守课程',
                          );
                          return;
                        }
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
                subtitle: '签到成功后，继续检查本次课后续的课间与课后签到',
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
