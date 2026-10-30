import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/schedule/academic_schedule.dart';
import 'package:xmu_rollcall/core/cache/course_rollcalls_store.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/cache/session_lifecycle.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/schedule/academic_sync.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:cookie_jar/cookie_jar.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepo()) {
    switchUser(1);
  }
  void switchUser(int id) => state = AuthState(
    status: AuthStatus.signedIn,
    profile: UserProfile(id: id, name: 'Test'),
  );
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

class _Repository extends Fake implements RollcallRepository {
  final entered = Completer<void>();
  final pending = Completer<CourseCatalogSnapshot>();
  Future<CourseCatalogSnapshot> Function()? onFetch;
  @override
  Future<CourseCatalogSnapshot> fetchCourseCatalog() {
    if (!entered.isCompleted) entered.complete();
    return onFetch?.call() ?? pending.future;
  }
}

CourseCatalogSnapshot _catalog(String id) => CourseCatalogSnapshot(
  fetchedAt: DateTime(2026, 10, 29),
  rolesResolved: true,
  courses: [CatalogCourse(id: id, title: id)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'history excludes old cached courses without deleting their records',
    () async {
      SharedPreferences.setMockInitialValues({});
      final at = DateTime(2026, 10, 30);
      await AcademicScheduleStore.write(
        1,
        AcademicSchedule(
          term: '20261',
          monday: DateTime(2026, 9, 7),
          fetchedAt: at,
          rows: const [
            AcademicCourseRow(
              courseId: 'cloud',
              courseName: '示例计算课程',
              weekday: 5,
              firstPeriod: 5,
              lastPeriod: 6,
              startMinute: 870,
              endMinute: 970,
              weeks: {8},
            ),
          ],
        ),
      );
      await CourseCatalogStore.write(
        1,
        CourseCatalogSnapshot(
          fetchedAt: at,
          rolesResolved: true,
          academicTerm: '20261',
          courses: const [
            CatalogCourse(
              id: 'current',
              title: '示例计算课程',
              courseCode: '202620271U1000000000101',
            ),
            CatalogCourse(
              id: 'old',
              title: '示例计算课程',
              courseCode: '202520262U1000000000101',
            ),
          ],
        ),
      );
      for (final id in ['current', 'old']) {
        await CourseRollcallsStore.writeSuccess(
          userId: 1,
          courseId: id,
          courseTitle: '示例计算课程',
          at: at,
          records: [
            CourseRollcallRecord(
              courseId: id,
              courseTitle: '示例计算课程',
              rollcallId: id,
              rollcallTime: at,
              typeLabel: '数字',
              signedStatus: '已签到',
              platformStatus: 'on_call_fine',
            ),
          ],
        );
      }
      final repo = _Repository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          academicSyncProvider.overrideWithValue(_Sync()),
          rollcallRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      expect(
        (await container.read(
          courseHistoryProvider.future,
        )).map((r) => r.courseId),
        ['current'],
      );
      expect(
        (await CourseRollcallsStore.read(1, 'old'))!.records,
        hasLength(1),
      );
      expect(repo.entered.isCompleted, isFalse);
    },
  );

  test('account change cannot reuse an earlier catalog request', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = _Auth();
    final first = _Repository(), second = _Repository();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        academicSyncProvider.overrideWithValue(_Sync()),
        rollcallRepositoryProvider.overrideWith(
          (ref) => ref.watch(authControllerProvider).profile!.id == 1
              ? first
              : second,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(sessionLifecycleProvider);
    container.listen(courseCatalogProvider, (_, _) {});
    await first.entered.future;
    auth.switchUser(2);
    final newCatalog = container.read(courseCatalogProvider.future);
    first.pending.complete(_catalog('owner-one'));
    await Future<void>.delayed(Duration.zero);
    second.pending.complete(_catalog('owner-two'));
    expect((await newCatalog)!.courses.single.id, 'owner-two');
    expect(second.entered.isCompleted, isTrue);
    expect((await CourseCatalogStore.read(2))!.courses.single.id, 'owner-two');
    expect(await CourseCatalogStore.read(1), isNull);
  });

  test('invalidated request cannot restore a cleared catalog', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = _Repository();
    final next = Completer<CourseCatalogSnapshot>();
    var calls = 0;
    repo.onFetch = () => ++calls == 1 ? repo.pending.future : next.future;
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => _Auth()),
        academicSyncProvider.overrideWithValue(_Sync()),
        rollcallRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.listen(courseCatalogProvider, (_, _) {});
    await repo.entered.future;
    container.invalidate(courseCatalogProvider);
    final refreshed = container.read(courseCatalogProvider.future);
    repo.pending.complete(_catalog('before-clear'));
    await Future<void>.delayed(Duration.zero);
    expect(await CourseCatalogStore.read(1), isNull);
    next.complete(_catalog('after-clear'));
    expect((await refreshed)!.courses.single.id, 'after-clear');
    expect(
      (await CourseCatalogStore.read(1))!.courses.single.id,
      'after-clear',
    );
  });
}
