import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/history/history_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_sync.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:cookie_jar/cookie_jar.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

class _Sync extends AcademicSync {
  _Sync() : super(SecureStore.memory());
  @override
  Future<void> sync(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    bool force = false,
  }) async {}
}

class _Repo extends Fake implements RollcallRepository {
  int calls = 0;
  @override
  Future<CourseCatalogSnapshot> fetchCourseCatalog() async =>
      throw StateError('offline');
  @override
  Future<List<CourseRollcallRecord>> fetchCourseRollcalls({
    required Object courseId,
    required int studentId,
    String courseTitle = '',
  }) async {
    calls++;
    return [
      CourseRollcallRecord(
        courseId: '$courseId',
        courseTitle: courseTitle,
        rollcallId: 'new',
        rollcallTime: DateTime(2026, 10, 26, 8, 30),
        typeLabel: '数字',
        signedStatus: '已签到',
        platformStatus: 'on_call_fine',
      ),
    ];
  }
}

void main() {
  testWidgets(
    'failed initial catalog remains in the retry UI without uncaught automatic errors',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _Auth()),
            academicSyncProvider.overrideWithValue(_Sync()),
            rollcallRepositoryProvider.overrideWithValue(_Repo()),
          ],
          child: const MaterialApp(home: HistoryPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('拉取失败'), findsOneWidget);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      'visible history checks only due windows and pauses offscreen: $platform',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        var now = DateTime(2026, 10, 26, 8, 30);
        await CourseCatalogStore.write(
          1,
          CourseCatalogSnapshot(
            fetchedAt: now,
            rolesResolved: true,
            academicTerm: '20261',
            courses: const [CatalogCourse(id: 'c', title: '测试课')],
          ),
        );
        await AcademicScheduleStore.write(
          1,
          AcademicSchedule(
            term: '20261',
            monday: DateTime(2026, 9, 7),
            fetchedAt: now,
            rows: const [
              AcademicCourseRow(
                courseId: 'academic',
                courseName: '测试课',
                weekday: 1,
                firstPeriod: 1,
                lastPeriod: 1,
                startMinute: 480,
                endMinute: 540,
                weeks: {8},
              ),
            ],
          ),
        );
        await CourseRollcallsStore.writeSuccess(
          userId: 1,
          courseId: 'c',
          courseTitle: '测试课',
          records: const [],
          at: now,
        );
        final repo = _Repo();
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith((ref) => _Auth()),
            academicSyncProvider.overrideWithValue(_Sync()),
            rollcallRepositoryProvider.overrideWithValue(repo),
            courseHistoryClockProvider.overrideWithValue(() => now),
          ],
        );
        addTearDown(container.dispose);
        final visible = ValueNotifier(true);
        addTearDown(visible.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (context, active, child) =>
                    TickerMode(enabled: active, child: child!),
                child: const HistoryPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(repo.calls, 0);
        now = now.add(const Duration(minutes: 1));
        await tester.pump(const Duration(minutes: 1));
        await tester.pumpAndSettle();
        expect(repo.calls, 1);
        visible.value = false;
        await tester.pumpAndSettle();
        now = now.add(const Duration(minutes: 2));
        await tester.pump(const Duration(minutes: 2));
        await tester.pumpAndSettle();
        expect(repo.calls, 1);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        visible.value = true;
        await tester.pumpAndSettle();
        now = now.add(const Duration(minutes: 2));
        await tester.pump(const Duration(minutes: 2));
        expect(repo.calls, 1);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(repo.calls, 2);
        now = DateTime(2026, 10, 26, 10, 1);
        await tester.pump(const Duration(minutes: 1));
        await tester.pumpAndSettle();
        expect(
          repo.calls,
          3,
          reason: 'one final sync covers the closed lesson',
        );
        now = now.add(const Duration(minutes: 3));
        await tester.pump(const Duration(minutes: 3));
        await tester.pumpAndSettle();
        expect(
          repo.calls,
          3,
          reason: 'a stable closed history makes no further requests',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
