import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/desktop/desktop_workspace.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/monitor/course_watch.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/monitor/detection_window_setting.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/monitor/monitor_quick_control.dart';
import 'package:xmu_rollcall/features/monitor/monitor_status_line.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

class _Repository extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repository()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '测试'),
    );
  }
}

class _Monitor extends MonitorController {
  _Monitor(super.ref) : super(bootstrap: false);
  void seed(MonitorState value) => state = value;
}

void main() {
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  for (final dark in [false, true]) {
    testWidgets(
      'desktop actions and status stay independent through all phases, dark=$dark',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(960, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var now = DateTime(2026, 10, 30, 10);
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith((ref) => _Auth()),
            monitorControllerProvider.overrideWith(_Monitor.new),
            selectedDetectionWindowProvider.overrideWith(
              (ref) async => const DetectionWindow(),
            ),
            activeRollcallClockProvider.overrideWithValue(() => now),
          ],
        );
        addTearDown(container.dispose);
        final monitor =
            container.read(monitorControllerProvider.notifier) as _Monitor;
        const config = MonitorConfig(courseWatch: true);
        final today = CourseWatchWindow(
          hasSchedule: true,
          hasLessonsToday: true,
          completedToday: false,
          intervals: [
            (
              start: DateTime(2026, 10, 30, 14, 20),
              end: DateTime(2026, 10, 30, 14, 30),
            ),
          ],
        );
        final tomorrow = CourseWatchWindow(
          hasSchedule: true,
          hasLessonsToday: false,
          completedToday: false,
          intervals: [
            (
              start: DateTime(2026, 10, 31, 7, 50),
              end: DateTime(2026, 10, 31, 8),
            ),
          ],
        );
        final complete = CourseWatchWindow(
          hasSchedule: true,
          hasLessonsToday: true,
          completedToday: true,
          intervals: tomorrow.intervals,
        );
        final cases = [
          (
            id: 'idle',
            state: const MonitorState(config: config),
            text: '更新于 09:59:00',
          ),
          (
            id: 'countdown',
            state: MonitorState(
              config: config,
              running: true,
              nextPollAt: now.add(const Duration(seconds: 20)),
            ),
            text: '检测中，20 秒后再次检测',
          ),
          (
            id: 'waiting',
            state: MonitorState(
              config: config,
              running: true,
              waitingForWindow: true,
              discoveryWindow: today,
            ),
            text: '值守中，今日 14:20 开始检测',
          ),
          (
            id: 'no-class-today',
            state: MonitorState(
              config: config,
              running: true,
              waitingForWindow: true,
              discoveryWindow: tomorrow,
            ),
            text: '今日无检测安排，明天 07:50 开始检测',
          ),
          (
            id: 'no-schedule',
            state: const MonitorState(
              config: config,
              running: true,
              waitingForWindow: true,
              discoveryWindow: CourseWatchWindow(
                hasSchedule: false,
                hasLessonsToday: false,
                completedToday: false,
                intervals: [],
              ),
            ),
            text: '暂无可检测的课表安排，等待后续安排',
          ),
          (
            id: 'processing',
            state: const MonitorState(
              config: config,
              running: true,
              discovering: false,
              activityMessage: '等待同学签到：3/5 人',
            ),
            text: '等待同学签到：3/5 人',
          ),
          (
            id: 'missing-location',
            state: const MonitorState(
              config: config,
              running: true,
              discovering: false,
              activityMessage: '雷达签到需先为本课设置位置或完成一次成功签到',
            ),
            text: '雷达签到需先为本课设置位置或完成一次成功签到',
          ),
          (
            id: 'retry',
            state: MonitorState(
              config: config,
              running: true,
              consecutiveFailures: 1,
              nextPollAt: now.add(const Duration(seconds: 40)),
            ),
            text: '检测失败，40 秒后重试',
          ),
          (
            id: 'complete',
            state: MonitorState(
              config: config,
              running: true,
              waitingForWindow: true,
              discoveryWindow: complete,
            ),
            text: '今日值守已完成，明天 07:50 开始检测',
          ),
        ];
        for (final scenario in cases) {
          monitor.seed(scenario.state);
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: desktopCaptureTheme(
                    dark ? AppTheme.dark() : AppTheme.light(),
                  ).copyWith(platform: TargetPlatform.windows),
                  home: DesktopWorkspace(
                    title: '签到',
                    subtitle: '10月30日  周五',
                    actions: const [
                      MonitorQuickControl(style: MonitorControlStyle.toolbar),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          MonitorStatusLine(fallback: '更新于 09:59:00'),
                          Expanded(
                            child: EmptyHint(
                              icon: Icons.inbox_outlined,
                              title: '暂无进行中的签到',
                              detail: '可手动刷新，发现的签到会显示在这里',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(scenario.text), findsOneWidget);
          final palette = AppPalette.of(
            tester.element(find.text(scenario.text)),
          );
          expect(
            tester.widget<Text>(find.text(scenario.text)).style!.color,
            scenario.id == 'retry' ? palette.danger : palette.muted,
          );
          if (scenario.state.running) {
            expect(
              tester.widget<Text>(find.text('暂停值守')).style!.color,
              palette.ink,
            );
          }
          expect(
            find.text(scenario.state.running ? '暂停值守' : '开始值守'),
            findsOneWidget,
          );
          expect(
            tester
                .getTopLeft(find.byKey(const ValueKey('monitor-status-line')))
                .dy,
            greaterThan(
              tester
                  .getBottomLeft(
                    find.text(scenario.state.running ? '暂停值守' : '开始值守'),
                  )
                  .dy,
            ),
          );
          if (scenario.id == 'countdown') {
            now = now.add(const Duration(seconds: 1));
            await tester.pump(const Duration(seconds: 1));
            expect(find.text('检测中，19 秒后再次检测'), findsOneWidget);
            now = now.subtract(const Duration(seconds: 1));
          }
          await captureDesktopUi(
            tester,
            'monitor-status-${scenario.id}-${dark ? 'dark' : 'light'}',
          );
        }
        final labelRect = tester.getRect(find.text('暂停值守'));
        await tester.tap(find.text('暂停值守'));
        await tester.pumpAndSettle();
        expect(find.text('开始值守'), findsOneWidget);
        expect(tester.getRect(find.text('开始值守')), labelRect);
        expect(find.text('更新于 09:59:00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
