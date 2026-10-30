import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/monitor/course_watch.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/monitor/monitor_status_line.dart';

void main() {
  final now = DateTime(2026, 10, 30, 10);
  CourseWatchWindow plan({
    bool today = true,
    bool completed = false,
    bool schedule = true,
    bool tomorrow = false,
    bool empty = false,
  }) => CourseWatchWindow(
    hasSchedule: schedule,
    hasLessonsToday: today,
    completedToday: completed,
    intervals: empty
        ? []
        : [
            (
              start: DateTime(2026, 10, tomorrow ? 31 : 30, 14, 20),
              end: DateTime(2026, 10, tomorrow ? 31 : 30, 14, 30),
            ),
          ],
  );
  String label(
    MonitorState state, {
    DetectionWindow? window,
    int pending = 0,
    int completed = 0,
  }) => monitorStatusText(
    monitor: state,
    now: now,
    fallback: '更新于 09:59:00',
    window: window,
    pendingCount: pending,
    completedCount: completed,
  );
  for (final watch in [false, true]) {
    for (final auto in [false, true]) {
      for (final full in [false, true]) {
        final config = MonitorConfig(
          courseWatch: watch,
          autoAnswer: auto,
          completeProbe: full,
        );
        test(
          'independent options preserve idle, pending, completion and retry semantics: watch=$watch auto=$auto full=$full',
          () {
            final idle = MonitorState(config: config);
            expect(label(idle), '更新于 09:59:00');
            expect(label(idle, pending: 1, completed: 1), '有 1 项待签到');
            expect(label(idle, completed: 1), '当前签到已完成');
            final running = idle.copyWith(
              running: true,
              nextPollAt: now.add(const Duration(seconds: 20)),
            );
            expect(label(running), '检测中，20 秒后再次检测');
            expect(label(running, pending: 1), '有 1 项待签到，20 秒后再次检测');
            expect(label(running.copyWith(nextPollAt: now)), '正在检测');
            expect(
              label(running.copyWith(consecutiveFailures: 1)),
              '检测失败，20 秒后重试',
            );
            if (auto) {
              expect(label(running.copyWith(discovering: false)), '正在处理自动签到');
            }
          },
        );
      }
    }
  }
  for (final auto in [false, true]) {
    for (final full in [false, true]) {
      test(
        'watch waits for real dates, remaining lessons and empty schedules: auto=$auto full=$full',
        () {
          final state = MonitorState(
            config: MonitorConfig(
              courseWatch: true,
              autoAnswer: auto,
              completeProbe: full,
            ),
            running: true,
            waitingForWindow: true,
          );
          expect(
            label(state.copyWith(discoveryWindow: plan())),
            '值守中，今日 14:20 开始检测',
          );
          expect(
            label(state.copyWith(discoveryWindow: plan()), completed: 1),
            '签到已完成，继续值守，今日 14:20 开始检测',
          );
          expect(
            label(
              state.copyWith(
                discoveryWindow: plan(today: false, tomorrow: true),
              ),
            ),
            '今日无检测安排，明天 14:20 开始检测',
          );
          expect(
            label(state.copyWith(discoveryWindow: plan(empty: true))),
            '今日检测时段已结束，等待后续安排',
          );
          expect(
            label(
              state.copyWith(
                discoveryWindow: plan(
                  schedule: false,
                  today: false,
                  empty: true,
                ),
              ),
            ),
            '暂无可检测的课表安排，等待后续安排',
          );
          // Successful lessons are suppressed only by the non-full planner.
          if (!full) {
            expect(
              label(
                state.copyWith(
                  discoveryWindow: plan(completed: true, tomorrow: true),
                ),
              ),
              '今日值守已完成，明天 14:20 开始检测',
            );
          }
          expect(
            label(
              state.copyWith(
                discoveryWindow: plan(completed: true, tomorrow: true),
              ),
              pending: 1,
            ),
            '有 1 项待签到，明天 14:20 开始检测',
          );
        },
      );
    }
  }
  test(
    'idle mode selection and stopped plans keep ordinary range feedback',
    () {
      for (final watch in [false, true]) {
        final idle = MonitorState(
          config: MonitorConfig(courseWatch: watch),
          running: false,
          waitingForWindow: true,
          discoveryWindow: plan(),
          lastPollAt: now.subtract(const Duration(minutes: 5)),
          nextPollAt: now.add(const Duration(seconds: 10)),
        );
        expect(
          monitorStatusText(
            monitor: idle,
            now: now,
            fallback: '课外暂停',
            window: const DetectionWindow(),
          ),
          '课外暂停',
        );
      }
    },
  );
  test('ordinary daily clock and watch planning remain independent', () {
    final daily = DetectionWindow(
      enabled: true,
      startMinute: 14 * 60,
      endMinute: 18 * 60,
    );
    final waiting = MonitorState(
      config: const MonitorConfig(),
      running: true,
      waitingForWindow: true,
    );
    expect(label(waiting, window: daily), '等待检测时段，今日 14:00 开始检测');
    final watch = waiting.copyWith(
      config: const MonitorConfig(courseWatch: true),
      discoveryWindow: plan(),
    );
    expect(label(watch, window: const DetectionWindow()), '值守中，今日 14:20 开始检测');
    expect(
      label(
        watch.copyWith(
          running: false,
          waitingForWindow: true,
          consecutiveFailures: 3,
        ),
      ),
      '更新于 09:59:00',
    );
  });
}
