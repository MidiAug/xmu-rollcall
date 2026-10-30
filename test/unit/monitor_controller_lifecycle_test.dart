import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository_providers.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

class AuthRepo extends Fake implements AuthRepository {}

class Auth extends AuthController {
  Auth() : super(AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
  void logout() => state = const AuthState(status: AuthStatus.signedOut);
}

class Repo extends Fake implements RollcallRepository {
  int calls = 0;
  final entered = Completer<void>();
  Completer<List<RollcallItem>>? pending;
  @override
  Future<List<RollcallItem>> fetchActive({
    CancelToken? cancelToken,
    String? opId,
    bool manual = false,
  }) async {
    calls++;
    if (!entered.isCompleted) entered.complete();
    return pending?.future ?? Future.value([]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late Repo repo;
  late Auth auth;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'schedule_detection_only_v2': false,
      'monitor_interval': 60,
      'monitor_jitter': 0.0,
    });
    repo = Repo();
    auth = Auth();
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        rollcallRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });
  tearDown(() {
    PlatformHooks.onRollcallsDiscovered = null;
    container.dispose();
  });
  test('unsaved settings load sixty seconds', () async {
    SharedPreferences.setMockInitialValues({});
    container.read(monitorControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(monitorControllerProvider).config.intervalSeconds,
      60,
    );
  });

  test(
    'explicit main-account launch preference resumes desktop watch without discovery outside windows',
    () async {
      SharedPreferences.setMockInitialValues({
        'monitor_account_1_1_course_watch': true,
        'monitor_account_1_1_resume_watch': true,
      });
      final resumed = Completer<void>();
      final subscription = container.listen(monitorControllerProvider, (
        _,
        state,
      ) {
        if (state.running && !resumed.isCompleted) resumed.complete();
      });
      addTearDown(subscription.close);
      await resumed.future.timeout(const Duration(seconds: 2));
      expect(
        container.read(monitorControllerProvider).config.resumeWatch,
        isTrue,
      );
      expect(container.read(monitorControllerProvider).running, isTrue);
      expect(repo.calls, 0);
    },
  );

  test(
    'legacy five-second interval loads on the new ten-second grid',
    () async {
      SharedPreferences.setMockInitialValues({
        'schedule_detection_only_v2': false,
        'monitor_interval': 25,
      });
      container.read(monitorControllerProvider);
      await Future<void>.delayed(Duration.zero);
      final state = container.read(monitorControllerProvider);
      expect(state.loadingSettings, isFalse);
      expect(state.config.intervalSeconds, 30);
      expect(state.config.autoAnswer, isFalse);
      expect(state.running, isFalse);
      expect(repo.calls, 0);
    },
  );

  test(
    'concurrent starts share one operation and finish settings load first',
    () async {
      final ctrl = container.read(monitorControllerProvider.notifier);
      final first = ctrl.startAsync();
      final second = ctrl.startAsync();
      expect(identical(first, second), isTrue);
      expect(await first, StartMonitorResult.started);
      expect(container.read(monitorControllerProvider).config.enabled, isTrue);
      expect(
        container.read(monitorControllerProvider).config.intervalSeconds,
        60,
      );
      await repo.entered.future;
      expect(repo.calls, 1);
    },
  );

  test('stop during initialization cancels startup', () async {
    final ctrl = container.read(monitorControllerProvider.notifier);
    final start = ctrl.startAsync();
    ctrl.stop();
    expect(await start, StartMonitorResult.cancelled);
    expect(container.read(monitorControllerProvider).running, isFalse);
    expect(repo.calls, 0);
  });

  test(
    'account logout stops the task and rejects an in-flight response',
    () async {
      repo.pending = Completer<List<RollcallItem>>();
      final ctrl = container.read(monitorControllerProvider.notifier);
      await ctrl.startAsync();
      await repo.entered.future;
      auth.logout();
      expect(container.read(monitorControllerProvider).running, isFalse);
      repo.pending!.complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(monitorControllerProvider).lastPollAt, isNull);
      expect(container.read(monitorControllerProvider).nextPollAt, isNull);
    },
  );

  test(
    'discovery forwards full fresh metadata and drops a stopped run',
    () async {
      final received = <List<RollcallItem>>[];
      final delivered = Completer<void>();
      PlatformHooks.onRollcallsDiscovered = (items) async {
        received.add(items);
        if (!delivered.isCompleted) delivered.complete();
      };
      final first = RollcallItem.fromJson({
        'rollcall_id': 9,
        'course_title': '工程伦理',
        'is_radar': true,
      });
      repo.pending = Completer<List<RollcallItem>>();
      final ctrl = container.read(monitorControllerProvider.notifier);
      await ctrl.startAsync();
      await repo.entered.future;
      repo.pending!.complete([first]);
      await delivered.future;
      expect(received.single.single.courseTitle, '工程伦理');
      expect(received.single.single.type, RollcallType.radar);
      await Future<void>.delayed(Duration.zero);
      repo.pending = Completer<List<RollcallItem>>();
      ctrl.pollNow();
      await Future<void>.delayed(Duration.zero);
      ctrl.stop();
      repo.pending!.complete([first]);
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(1));
    },
  );

  test('no session cannot start polling', () async {
    auth.logout();
    final ctrl = container.read(monitorControllerProvider.notifier);
    expect(await ctrl.startAsync(), StartMonitorResult.notSignedIn);
    expect(container.read(monitorControllerProvider).starting, isFalse);
    expect(repo.calls, 0);
  });
  test(
    'changing semester Monday reschedules a waiting monitor, without starting a stopped one',
    () async {
      await (await SharedPreferences.getInstance()).setBool(
        'schedule_detection_only_v2',
        true,
      );
      final now = DateTime.now();
      final term = currentSemester(now);
      final start =
          academicMondays[term] ??
          DateTime(now.year, now.month, now.day - now.weekday + 1);
      final week = semesterDate(now).difference(start).inDays ~/ 7;
      final minute = now.hour * 60 + now.minute;
      await AcademicScheduleStore.write(
        1,
        AcademicSchedule(
          term: term,
          monday: start,
          fetchedAt: now,
          rows: [
            {
              'KCDM': 'fake',
              'KCMC': '测试课程',
              'BJDM': 'A',
              'XQ': now.weekday,
              'ZCBH': List.generate(60, (i) => i == week ? '1' : '0').join(),
              'KSJCDM': 1,
              'JSJCDM': 2,
              'startMinute': (minute - 10).clamp(0, 1438),
              'endMinute': (minute + 10).clamp(1, 1439),
            },
          ].map(AcademicCourseRow.fromJson).toList(),
        ),
      );
      await SemesterPreferences.save(
        1,
        term,
        start.add(const Duration(days: 7)),
      );
      final ctrl = container.read(monitorControllerProvider.notifier);
      container.read(academicRevisionProvider.notifier).state++;
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, 0);
      expect(container.read(monitorControllerProvider).running, isFalse);
      expect(await ctrl.startAsync(), StartMonitorResult.started);
      for (var i = 0; i < 30; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(repo.calls, 0);
      expect(container.read(monitorControllerProvider).running, isTrue);
      await SemesterPreferences.save(1, term, null);
      container.read(academicRevisionProvider.notifier).state++;
      await repo.entered.future.timeout(const Duration(seconds: 2));
      expect(repo.calls, 1);
      ctrl.stop();
    },
  );
}
