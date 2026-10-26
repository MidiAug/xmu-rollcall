import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count_row.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository_providers.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '测试同学'),
    );
  }
}

class _Repo extends Fake implements RollcallRepository {
  int calls = 0;
  Completer<AttendanceCount>? pending;
  @override
  Future<AttendanceCount> fetchAttendanceCount(int id, {String? opId}) async {
    calls++;
    return pending?.future ?? AttendanceCount(calls, 245);
  }
}

void main() {
  setUpAll(() async {
    for (final font in {
      'PauseUi': 'C:/Windows/Fonts/msyh.ttc',
      'MaterialIcons':
          'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final file = File(font.value);
      if (file.existsSync()) {
        await (FontLoader(
          font.key,
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
  });
  for (final scenario in [
    (width: 320.0, scale: 1.3, dark: true),
    (width: 960.0, scale: 1.0, dark: false),
  ]) {
    testWidgets('manual pause and automatic count rules at $scenario', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(scenario.width, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      final assist = _Repo();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(ref, bootstrap: false),
          ),
          attendanceCountClockProvider.overrideWithValue(
            tester.binding.clock.now,
          ),
          rollcallRepositoryForProvider(null).overrideWithValue(repo),
          rollcallRepositoryForProvider(2).overrideWithValue(assist),
        ],
      );
      addTearDown(container.dispose);
      final capture = GlobalKey();
      Future<void> show({
        bool visible = true,
        int id = 1,
        int? account,
        bool expired = false,
      }) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: (scenario.dark ? AppTheme.dark() : AppTheme.light())
                .copyWith(
                  platform: scenario.width < 600
                      ? TargetPlatform.android
                      : TargetPlatform.windows,
                  textTheme:
                      (scenario.dark ? AppTheme.dark() : AppTheme.light())
                          .textTheme
                          .apply(fontFamily: 'PauseUi'),
                ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: capture,
                  child: Container(
                    color: (scenario.dark ? AppTheme.dark() : AppTheme.light())
                        .colorScheme
                        .surface,
                    padding: const EdgeInsets.all(16),
                    child: TickerMode(
                      enabled: visible,
                      child: AttendanceCountRow(
                        rollcallId: id,
                        assistUserId: account,
                        expired: expired,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> screenshot(String state) async {
        if (Platform.environment['CAPTURE_ATTENDANCE_PAUSE_UI'] != '1') return;
        await tester.runAsync(() async {
          final img =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          final dir = await Directory(
            'build/desktop-ui-review',
          ).create(recursive: true);
          await File(
            '${dir.path}/attendance-${scenario.width}-$state.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          img.dispose();
        });
      }

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await show();
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      await screenshot('running');
      await tester.tap(find.byTooltip('暂停刷新人数'));
      await tester.pumpAndSettle();
      expect(find.text('已暂停'), findsOneWidget);
      expect(find.text('已签到人数 1 / 245 人'), findsOneWidget);
      await screenshot('paused');
      // Returning to a remounted card must retain both pause and last count.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox(),
        ),
      );
      await tester.pump();
      await show();
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(find.text('已暂停'), findsOneWidget);
      expect(find.text('已签到人数 1 / 245 人'), findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      final monitor = container.read(monitorControllerProvider.notifier);
      monitor.setAttendanceIntervalSeconds(45);
      await tester.pump();
      await show(visible: false);
      await tester.pump(const Duration(seconds: 60));
      await show();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repo.calls, 1);
      await tester.tap(find.byTooltip('继续刷新人数'));
      await tester.pump(const Duration(milliseconds: 1));
      expect(repo.calls, 2);
      repo.pending = Completer<AttendanceCount>();
      await tester.pump(const Duration(seconds: 45));
      expect(repo.calls, 3);
      await tester.tap(find.byTooltip('暂停刷新人数'));
      repo.pending!.complete(const AttendanceCount(33, 245));
      repo.pending = null;
      await tester.pump();
      await tester.pump(const Duration(seconds: 60));
      expect(repo.calls, 3);
      expect(find.text('已签到人数 33 / 245 人'), findsOneWidget);
      monitor.setAutomaticAnswer(true);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byTooltip('继续刷新人数'), findsNothing);
      expect(find.byTooltip('暂停刷新人数'), findsNothing);
      expect(find.text('已暂停'), findsNothing);
      expect(repo.calls, 4);
      monitor.setAnswerWaitMode(AnswerWaitMode.count);
      await tester.pump();
      expect(find.byTooltip('暂停刷新人数'), findsNothing);
      monitor.setAnswerWaitMode(AnswerWaitMode.none);
      await tester.pump();
      expect(find.byTooltip('暂停刷新人数'), findsOneWidget);
      monitor.setAnswerWaitMode(AnswerWaitMode.count);
      monitor.setAutomaticAnswer(false);
      await tester.pump();
      await tester.tap(find.byTooltip('暂停刷新人数'));
      await tester.pump();
      await show(id: 2);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repo.calls, 5); // A new activity does not inherit pause.
      await tester.tap(find.byTooltip('暂停刷新人数'));
      await tester.pump();
      monitor.setAutomaticAnswer(true);
      await tester.pump();
      await show(id: 2, account: 2);
      await tester.pumpAndSettle();
      expect(assist.calls, 1);
      expect(
        find.byTooltip('暂停刷新人数'),
        findsOneWidget,
      ); // Owner rule cannot hide another identity's control.
      await show(id: 2, account: 2, expired: true);
      await tester.pump(const Duration(seconds: 60));
      expect(assist.calls, 1);
      expect(find.byTooltip('暂停刷新人数'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
