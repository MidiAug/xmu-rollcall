import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/assist_service.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_repository.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_providers.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_assignment_store.dart';
import '../fixtures/ta_http_fixture.dart';

class _AuthRepository extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepository()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 11, name: 'owner'),
    );
  }
  void logout() => state = const AuthState(status: AuthStatus.signedOut);
  void loginAs(int id) => state = AuthState(
    status: AuthStatus.signedIn,
    profile: UserProfile(id: id, name: 'owner'),
  );
}

class _SessionService extends Fake implements AssistService {
  int calls = 0;
  @override
  Future<void> ensureSession(AssistIdentity identity) async {
    calls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real grading provider binds selected account client and cancels descendants on switch/logout',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ownerFixture = TaHttpFixture(), assistFixture = TaHttpFixture();
      final owner = await ownerFixture.repository(),
          assist = await assistFixture.repository();
      final service = _SessionService();
      final auth = _Auth();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => auth),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(
              ref,
              bootstrap: false,
              initial: const AssistUiState(
                ready: true,
                identities: [
                  AssistIdentity(
                    userId: 22,
                    displayName: 'assist',
                    kind: AssistCredentialKind.session,
                  ),
                ],
              ),
            ),
          ),
          assistServiceProvider.overrideWith((ref) async => service),
          homeworkRepositoryProvider.overrideWith(
            (ref) => HomeworkRepository(
              http: ref.watch(selectedRollcallAccountProvider) == null
                  ? owner.http
                  : assist.http,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(owner.dispose);
      addTearDown(assist.dispose);
      final subscription = container.listen(taRepositoryProvider, (_, _) {});
      final a = await container.read(taRepositoryProvider.future);
      await a.assignments(91);
      expect(a.cachedAssignments(91), isNotNull);
      subscription.close();
      await Future<void>.delayed(Duration.zero);
      expect(await container.read(taRepositoryProvider.future), same(a));
      final page = a.fork();
      expect(identical(a.http, owner.http), isTrue);
      container.read(selectedRollcallAccountProvider.notifier).state = 22;
      final b = await container.read(taRepositoryProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(a.active, isFalse);
      expect(a.cachedAssignments(91), isNull);
      expect(b.cachedAssignments(91), isNull);
      expect(page.active, isFalse);
      expect(identical(b.http, assist.http), isTrue);
      expect(service.calls, 0);
      final ownerRequests = ownerFixture.requests.length;
      await b.saveScore(81, 1, '90');
      expect(service.calls, 1);
      expect(ownerFixture.requests.length, ownerRequests);
      expect(assistFixture.scores[1], 90);
      await b.assignments(91);
      expect((await TaAssignmentStore(11).read(91))!.items.single.graded, 0);
      expect((await TaAssignmentStore(22).read(91))!.items.single.graded, 1);
      auth.logout();
      await expectLater(
        container.read(taRepositoryProvider.future),
        throwsStateError,
      );
      expect(b.active, isFalse);
      expect(await TaAssignmentStore(22).read(91), isNotNull);
      auth.loginAs(33);
      final c = await container.read(taRepositoryProvider.future);
      await c.restoreAssignments(91);
      expect(c.cachedAssignments(91), isNull);
      await c.assignments(91);
      expect(await TaAssignmentStore(33).read(91), isNotNull);
      expect((await TaAssignmentStore(11).read(91))!.items.single.graded, 0);
    },
  );
}
