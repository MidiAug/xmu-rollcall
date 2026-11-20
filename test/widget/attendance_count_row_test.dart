import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../fixtures/preview_fonts.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count_row.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/session_prior_panel.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository_providers.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

class _Repo extends Fake implements RollcallRepository {
  int calls = 0;
  bool fail = false;
  Completer<AttendanceCount>? pending;
  @override
  Future<AttendanceCount> fetchAttendanceCount(int id, {String? opId}) async {
    calls++;
    if (fail) throw StateError('offline');
    return pending?.future ?? AttendanceCount(calls, 40);
  }
}

class _Catalog extends CourseCatalogNotifier {
  @override
  Future<CourseCatalogSnapshot?> build() async => CourseCatalogSnapshot(
    fetchedAt: DateTime(2026, 10, 26),
    courses: const [CatalogCourse(id: '9', title: '测试课程')],
  );
}

void main() {
  for (final completed in [false, true]) {
    testWidgets(
      'task card resize retains pending count and refresh cadence completed=$completed',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1100, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _Repo()..pending = Completer<AttendanceCount>();
        final width = ValueNotifier(760.0);
        addTearDown(width.dispose);
        final container = ProviderContainer(
          overrides: [
            attendanceCountClockProvider.overrideWithValue(
              tester.binding.clock.now,
            ),
            authControllerProvider.overrideWith((ref) => _Auth()),
            assistControllerProvider.overrideWith(
              (ref) => AssistController(ref, bootstrap: false),
            ),
            rollcallRepositoryForProvider(null).overrideWithValue(repo),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light().copyWith(
                platform: TargetPlatform.windows,
              ),
              home: Scaffold(
                body: Center(
                  child: ValueListenableBuilder<double>(
                    valueListenable: width,
                    builder: (context, value, _) => SizedBox(
                      width: value,
                      child: RollcallTaskCard(
                        item: RollcallItem(
                          rollcallId: 1,
                          courseTitle: '测试课程',
                          createdByName: '老师',
                          type: RollcallType.number,
                          status: completed ? 'on_call_fine' : 'on_call',
                          rollcallStatus: 'on_call',
                          isExpired: false,
                          scored: false,
                          numberCode: '1234',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        expect(repo.calls, 1);
        final state = tester.state(find.byType(AttendanceCountRow));
        width.value = 480;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        expect(
          repo.calls,
          1,
          reason: 'reflow must not issue a second in-flight request',
        );
        expect(tester.state(find.byType(AttendanceCountRow)), same(state));
        repo.pending!.complete(const AttendanceCount(30, 40));
        await tester.pumpAndSettle();
        expect(find.text('30 / 40 人'), findsOneWidget);
        for (final value in [760.0, 480.0, 800.0, 500.0]) {
          width.value = value;
          await tester.pumpAndSettle();
          expect(find.text('查询中…'), findsNothing);
          expect(find.text('30 / 40 人'), findsOneWidget);
          expect(repo.calls, 1);
        }
        repo.pending = null;
        final interval = container
            .read(monitorControllerProvider)
            .config
            .effectiveAttendanceIntervalSeconds;
        await tester.pump(Duration(seconds: interval + 1));
        await tester.pump();
        expect(repo.calls, completed ? 1 : 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'compact tooltip centers on visible count and pause stays separate',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(loadDesktopPreviewFonts);
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [
          attendanceCountClockProvider.overrideWithValue(
            tester.binding.clock.now,
          ),
          authControllerProvider.overrideWith((ref) => _Auth()),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(ref, bootstrap: false),
          ),
          rollcallRepositoryForProvider(null).overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light().copyWith(
                platform: TargetPlatform.windows,
              ),
              home: const Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 300,
                    child: AttendanceCountRow(
                      rollcallId: 1,
                      expired: false,
                      compact: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final anchor = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message!.startsWith('已签到人数'),
      );
      expect(tester.getSize(anchor).width, lessThan(150));
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(anchor));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final hint = find.textContaining('已签到人数');
      expect(hint, findsOneWidget);
      expect(
        tester.getCenter(hint).dx,
        closeTo(tester.getCenter(anchor).dx, 1),
      );
      Future<void> screenshot(String name) async {
        if (Platform.environment['CAPTURE_COUNT_HOVER'] != '1') return;
        await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/count-hover').create(recursive: true);
          await File(
            'build/count-hover/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await screenshot('tooltip');
      final pause = find.byTooltip('暂停刷新人数');
      await mouse.moveTo(tester.getCenter(pause));
      await tester.pump(const Duration(milliseconds: 250));
      await screenshot('pause-hover');
      await tester.tap(pause);
      await tester.pumpAndSettle();
      expect(find.byTooltip('继续刷新人数'), findsOneWidget);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'counts refresh after signing, retain failures, and pause in background',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [
          attendanceCountClockProvider.overrideWithValue(
            tester.binding.clock.now,
          ),
          authControllerProvider.overrideWith((ref) => _Auth()),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(ref, bootstrap: false),
          ),
          rollcallRepositoryForProvider(null).overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AttendanceCountRow(rollcallId: 1, expired: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('已签到人数 1 / 40 人'), findsOneWidget);
      expect(find.textContaining('后刷新'), findsOneWidget);
      await tester.pump(const Duration(seconds: 19));
      expect(repo.calls, 1);
      repo.pending = Completer<AttendanceCount>();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('刷新中'), findsOneWidget);
      expect(find.text('已签到人数 1 / 40 人'), findsOneWidget);
      repo.pending!.complete(const AttendanceCount(2, 40));
      repo.pending = null;
      await tester.pump();
      expect(find.text('已签到人数 2 / 40 人'), findsOneWidget);
      repo.fail = true;
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('已签到人数 2 / 40 人'), findsOneWidget);
      expect(find.byIcon(Icons.sync_problem_rounded), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 60));
      expect(repo.calls, 3);
      repo.fail = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repo.calls, 4);
      container
          .read(monitorControllerProvider.notifier)
          .setAttendanceIntervalSeconds(45);
      await tester.pump();
      await tester.pump(const Duration(seconds: 44));
      expect(repo.calls, 4);
      await tester.pump(const Duration(seconds: 1));
      expect(repo.calls, 5);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 60));
      expect(repo.calls, 5);
    },
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('focus and tab changes preserve count deadline on $platform', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(ref, bootstrap: false),
          ),
          rollcallRepositoryForProvider(null).overrideWithValue(repo),
          attendanceCountClockProvider.overrideWithValue(
            tester.binding.clock.now,
          ),
        ],
      );
      addTearDown(container.dispose);
      Future<void> show({
        bool visible = true,
        int id = 1,
        bool expired = false,
      }) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: TickerMode(
                enabled: visible,
                child: AttendanceCountRow(rollcallId: id, expired: expired),
              ),
            ),
          ),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await show();
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 20));
      expect(repo.calls, platform == TargetPlatform.windows ? 2 : 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repo.calls, 2);
      await show(visible: false);
      await tester.pump(const Duration(seconds: 5));
      await show();
      await tester.pump(const Duration(milliseconds: 1));
      expect(repo.calls, 2);
      await tester.pump(const Duration(seconds: 15, milliseconds: 1));
      expect(repo.calls, 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 40));
      expect(repo.calls, 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repo.calls, 4);
      await show(id: 2);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repo.calls, 5);
      await show(id: 2, expired: true);
      await tester.pump(const Duration(seconds: 40));
      expect(repo.calls, 5);
      expect(find.textContaining('后刷新'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('missing timetable explains history is available separately', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          courseCatalogProvider.overrideWith(_Catalog.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SessionPriorPanel(
              courseId: '9',
              currentType: RollcallType.qrcode,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('本课未提供课表时段，过往签到可在签到记录中查看'), findsOneWidget);
  });
}
