import 'dart:async';

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
