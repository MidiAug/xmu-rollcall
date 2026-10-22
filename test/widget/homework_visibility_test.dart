import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/homework/homework_hub_page.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_overview.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

class _Todos extends HomeworkTodosNotifier {
  @override
  Future<List<HomeworkItem>> build() async => [];
}

class _Overview extends HomeworkOverviewNotifier {
  static int checks = 0;
  @override
  Future<HomeworkOverview> build() async {
    ref.keepAlive();
    return const HomeworkOverview([
      HomeworkItem(id: 1, title: '缓存作业', courseName: '测试课程', type: 'exam'),
    ]);
  }

  @override
  Future<void> ensureFresh({bool force = false}) async {
    checks++;
  }
}

void main() {
  testWidgets(
    'automatic checks stop off-tab and in background, and resume in foreground',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      _Overview.checks = 0;
      final tab = ValueNotifier(AppDestination.homework);
      addTearDown(tab.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _Auth()),
            homeworkTodosProvider.overrideWith(_Todos.new),
            homeworkOverviewProvider.overrideWith(_Overview.new),
            homeworkClockProvider.overrideWithValue(tester.binding.clock.now),
            currentTeachingCoursesProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<AppDestination>(
                valueListenable: tab,
                builder: (context, current, _) => ShellTabScope(
                  current: current,
                  retapEpoch: 0,
                  retapDestination: null,
                  child: const HomeworkHubPage(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initial = _Overview.checks;
      expect(initial, greaterThan(0));
      final initialPosition = tester.getTopLeft(find.text('缓存作业'));
      for (var i = 0; i < 5; i++) {
        tab.value = AppDestination.rollcall;
        await tester.pumpAndSettle();
        tab.value = AppDestination.homework;
        await tester.pump();
        expect(find.text('缓存作业'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.text('缓存作业')), initialPosition);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(
        find.text('缓存作业'),
        findsOneWidget,
        reason: 'Losing window focus must not unmount cached homework rows',
      );
      expect(tester.getTopLeft(find.text('缓存作业')), initialPosition);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_Overview.checks, initial);
      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();
      expect(_Overview.checks, initial + 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 10));
      expect(_Overview.checks, initial + 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      final resumed = _Overview.checks;
      expect(resumed, initial + 2);
      tab.value = AppDestination.rollcall;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 10));
      expect(_Overview.checks, resumed);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
