import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/auth_session.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/schedule/academic_sync.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';

class _Repository extends Fake implements AuthRepository {
  void Function()? onSignOut;
  static const profile = UserProfile(id: 1, name: 'Test');

  @override
  Future<bool> hasStoredCookies() async => true;
  @override
  Future<UserProfile?> cachedProfile() async => profile;
  @override
  Future<UserProfile?> tryRestoreSession() async => profile;
  @override
  Future<UserProfile> signIn({
    required String username,
    required String password,
    bool rememberPassword = false,
  }) async => profile;
  @override
  Future<void> signOut() async => onSignOut?.call();
}

class _AcademicSync extends AcademicSync {
  _AcademicSync(super.store);
  final calls = <({int uid, bool force, String? username, String? password})>[];
  Completer<void>? pending;

  @override
  Future<void> sync(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    bool force = false,
  }) async {
    calls.add((uid: uid, force: force, username: username, password: password));
    await pending?.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Repository repo;
  late _AcademicSync sync;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final store = SecureStore.memory();
    repo = _Repository();
    sync = _AcademicSync(store);
    container = ProviderContainer(
      overrides: [
        secureStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(repo),
        academicSyncProvider.overrideWithValue(sync),
        authControllerProvider.overrideWith(createAppAuthController),
        assistControllerProvider.overrideWith(
          (ref) => AssistController(
            ref,
            bootstrap: false,
            initial: const AssistUiState(ready: true),
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  test(
    'app wiring syncs restored and new sessions, stops before logout',
    () async {
      final auth = container.read(authControllerProvider.notifier);
      await auth.bootstrap();
      expect(sync.calls.single, (
        uid: 1,
        force: false,
        username: null,
        password: null,
      ));

      await auth.signIn(username: 'test-user', password: 'test-password');
      await Future<void>.delayed(Duration.zero);
      expect(sync.calls.last, (
        uid: 1,
        force: false,
        username: 'test-user',
        password: 'test-password',
      ));
      expect(container.read(academicRevisionProvider), 1);

      final monitor = container.read(monitorControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      monitor.debugArmRunning();
      expect(container.read(monitorControllerProvider).running, isTrue);
      repo.onSignOut = () {
        expect(container.read(monitorControllerProvider).running, isFalse);
      };
      await auth.signOut();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
    },
  );

  test(
    'a sync finishing after session expiry does not signal a logged-in refresh',
    () async {
      sync.pending = Completer<void>();
      final auth = container.read(authControllerProvider.notifier);
      await auth.signIn(username: 'test-user', password: 'test-password');
      auth.expireSession();
      sync.pending!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(academicRevisionProvider), 0);
    },
  );

  test(
    'assist owner sharing uses persisted catalog without loading its provider',
    () async {
      await container.read(authControllerProvider.notifier).bootstrap();
      await CourseCatalogStore.write(
        1,
        CourseCatalogSnapshot(
          fetchedAt: DateTime(2026, 10, 29),
          courses: const [CatalogCourse(id: '10', title: 'Test course')],
        ),
      );
      final service = await container.read(assistServiceProvider.future);
      final courses = await service.courseCatalog!(
        container.read(sessionClientRegistryProvider).owner(),
      );
      expect(courses.single.id, '10');
      expect(courses.single.title, 'Test course');
    },
  );
}
