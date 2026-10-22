import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count_row.dart';
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
  Future<AttendanceCount> fetchAttendanceCount(int id) async {
    calls++;
    if (fail) throw StateError('offline');
    return pending?.future ?? AttendanceCount(calls, 40);
  }
}

void main() {
  testWidgets(
    'counts refresh after signing, retain failures, and pause in background',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = _Repo();
      final container = ProviderContainer(
        overrides: [
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
}
