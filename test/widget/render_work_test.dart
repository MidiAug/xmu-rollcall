import 'package:xmu_rollcall/features/history/history_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/core/cache/cache_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
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

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

class _Monitor extends MonitorController {
  _Monitor(super.ref) : super(bootstrap: false);
  void publish(MonitorState value) => state = value;
}

class _Window extends DetectionWindow {
  int checks = 0;
  @override
  bool allows(DateTime at) {
    checks++;
    return true;
  }
}

class _CountedRecord extends CourseRollcallRecord {
  _CountedRecord(int i)
    : at = DateTime(2026, 10, 1 + i % 28, i % 24, i % 60),
      super(
        courseId: 'course',
        courseTitle: '测试课程',
        rollcallId: '$i',
        rollcallTime: null,
        typeLabel: '数字签到',
        signedStatus: i.isEven ? '已签到' : '未签到',
        platformStatus: '',
      );
  static int reads = 0;
  final DateTime at;
  @override
  DateTime? get rollcallTime {
    reads++;
    return at;
  }
}

class _History extends CourseHistoryNotifier {
  @override
  Future<List<CourseRollcallRecord>> build() async =>
      List.generate(200, _CountedRecord.new);
  @override
  Future<void> ensureFresh({
    EnsureFreshReason reason = EnsureFreshReason.appear,
    String? courseId,
  }) async {}
}

void main() {
  testWidgets('history filtering reuses normalization for unchanged data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          courseHistoryProvider.overrideWith(_History.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
          home: const HistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-status-filter')));
    await tester.pumpAndSettle();
    _CountedRecord.reads = 0;
    await tester.tap(find.byKey(const ValueKey('shell-select-option-2')));
    await tester.pumpAndSettle();
    debugPrint(
      'history timestamp reads after filtering 200 rows: ${_CountedRecord.reads}',
    );
    expect(_CountedRecord.reads, lessThan(1000));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final scenario in ['logs', 'waiting', 'hidden']) {
      testWidgets('render work stays local for $scenario on $platform', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        var now = DateTime(2026, 10, 30, 10);
        final window = _Window();
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith((ref) => _Auth()),
            monitorControllerProvider.overrideWith(_Monitor.new),
            selectedDetectionWindowProvider.overrideWith((ref) async => window),
            activeRollcallClockProvider.overrideWithValue(() => now),
          ],
        );
        addTearDown(container.dispose);
        final monitor =
            container.read(monitorControllerProvider.notifier) as _Monitor;
        final plan = CourseWatchWindow(
          hasLessonsToday: true,
          completedToday: false,
          hasSchedule: true,
          intervals: [
            (
              start: DateTime(2026, 10, 30, 14, 20),
              end: DateTime(2026, 10, 30, 14, 30),
            ),
          ],
        );
        monitor.publish(
          MonitorState(
            config: MonitorConfig(
              courseWatch: platform == TargetPlatform.windows,
            ),
            running: true,
            waitingForWindow: true,
            discoveryWindow: plan,
          ),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light().copyWith(platform: platform),
              home: Scaffold(
                body: TickerMode(
                  enabled: scenario != 'hidden',
                  child: Column(
                    children: [
                      MonitorQuickControl(
                        style: platform == TargetPlatform.android
                            ? MonitorControlStyle.mastheadStatus
                            : MonitorControlStyle.toolbar,
                      ),
                      MonitorStatusLine(fallback: '课外暂停'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        var controls = 0, statuses = 0;
        final previous = debugOnRebuildDirtyWidget;
        debugOnRebuildDirtyWidget = (element, builtOnce) {
          previous?.call(element, builtOnce);
          if (element.widget is MonitorQuickControl) controls++;
          if (element.widget is MonitorStatusLine) statuses++;
        };
        addTearDown(() => debugOnRebuildDirtyWidget = previous);
        window.checks = 0;
        if (scenario == 'logs') {
          for (var i = 0; i < 20; i++) {
            monitor.publish(
              monitor.state.copyWith(
                logs: [PollLogEntry(at: now, ok: true, message: 'log $i')],
              ),
            );
            await tester.pump();
          }
        } else {
          for (var i = 0; i < 5; i++) {
            now = now.add(const Duration(seconds: 1));
            await tester.pump(const Duration(seconds: 1));
          }
        }
        debugPrint(
          '$scenario: controls=$controls status=$statuses windowChecks=${window.checks}',
        );
        expect(controls, 0);
        expect(statuses, 0);
        expect(window.checks, 0);
        if (platform == TargetPlatform.windows) {
          expect(find.text('值守中，今日 14:20 开始检测'), findsOneWidget);
        } else {
          expect(find.text('等待课表时段'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
