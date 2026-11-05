import 'package:xmu_rollcall/features/exams/exam_cache.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/exams/exam_models.dart';
import 'package:xmu_rollcall/features/exams/exam_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import '../fixtures/exam_adapter.dart';

class Repo extends Fake implements AuthRepository {}

class Auth extends AuthController {
  Auth() : super(Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late SharedPreferences prefs;
  late ExamAdapter adapter;
  late ProviderContainer c;
  late int identities;
  late bool sessionCurrent;
  ExamSnapshot cache(
    DateTime at, {
    String term = '20261',
    String course = '本地课程',
  }) => ExamSnapshot(
    term: term,
    at: at,
    exams: [AcademicExam(id: 'cached', course: course)],
  );
  Future<void> save(int uid, ExamSnapshot snapshot) => prefs.setString(
    examCacheKey(1, uid, snapshot.term),
    jsonEncode(snapshot.toJson()),
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 10, 31);
    adapter = ExamAdapter();
    identities = 0;
    sessionCurrent = true;
    c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => Auth()),
        assistControllerProvider.overrideWith(
          (ref) => AssistController(
            ref,
            bootstrap: false,
            initial: const AssistUiState(ready: true),
          ),
        ),
        examClockProvider.overrideWithValue(() => now),
        academicIdentityResolverProvider.overrideWithValue((uid) async {
          identities++;
          return AcademicIdentity(
            username: 'synthetic',
            isCurrent: () async => sessionCurrent,
          );
        }),
        academicSessionFactoryProvider.overrideWithValue(
          () => AcademicSession(
            store: SecureStore.memory({SecureStore.keyUserId: '1'}),
            dio: Dio()..httpClientAdapter = adapter,
            limiter: RateLimiter(minInterval: Duration.zero),
          ),
        ),
      ],
    );
  });
  tearDown(() => c.dispose());
  for (final uid in [1, 2]) {
    test(
      'fresh account $uid cache avoids auth; manual updates merge and throttle before auth',
      () async {
        if (uid == 2) {
          c.read(selectedRollcallAccountProvider.notifier).state = 2;
        }
        await save(uid, cache(now.subtract(const Duration(days: 1))));
        final sub = c.listen(examSnapshotProvider, (_, _) {});
        addTearDown(sub.close);
        expect(
          (await c.read(examSnapshotProvider.future)).exams.single.course,
          '本地课程',
        );
        await Future<void>.delayed(Duration.zero);
        expect(identities, 0);
        adapter.gate = Completer<void>();
        final notifier = c.read(examSnapshotProvider.notifier);
        final first = notifier.refresh();
        await adapter.entered.future;
        final second = notifier.refresh();
        expect(
          c.read(examSnapshotProvider).requireValue.exams.single.id,
          'cached',
        );
        adapter.gate!.complete();
        await Future.wait([first, second]);
        expect(identities, 1);
        expect(c.read(examSnapshotProvider).requireValue.exams.length, 3);
        expect(prefs.getString(examCacheKey(1, uid, '20261')), isNotNull);
        expect(
          prefs.getString(examCacheKey(1, uid == 1 ? 2 : 1, '20261')),
          isNull,
        );
        await expectLater(notifier.refresh(), throwsFormatException);
        expect(identities, 1);
      },
    );
  }
  for (final fails in [false, true]) {
    test(
      'stale cache published before network; failure=$fails preserves complete data',
      () async {
        await save(1, cache(now.subtract(const Duration(days: 8))));
        adapter
          ..gate = Completer<void>()
          ..failUnarranged = fails;
        final sub = c.listen(examSnapshotProvider, (_, _) {});
        addTearDown(sub.close);
        expect(
          (await c.read(examSnapshotProvider.future)).exams.single.id,
          'cached',
        );
        await adapter.entered.future;
        final notifier = c.read(examSnapshotProvider.notifier);
        final joined = notifier.refresh();
        if (fails) {
          final failed = expectLater(joined, throwsA(isA<DioException>()));
          adapter.gate!.complete();
          await failed;
          expect(
            c.read(examSnapshotProvider).requireValue.exams.single.id,
            'cached',
          );
          expect(
            readExamCache(prefs, 1, 1, '20261')!.exams.single.id,
            'cached',
          );
          now = now.add(const Duration(minutes: 1));
          await notifier.checkForUpdates();
          expect(identities, 1); // Persistent automatic failure backoff.
          adapter.failUnarranged = false;
          await notifier
              .refresh(); // User action bypasses auto backoff, not 15s gate.
          expect(identities, 2);
        } else {
          adapter.gate!.complete();
          await joined;
          expect(c.read(examSnapshotProvider).requireValue.exams.length, 3);
        }
      },
    );
  }
  test('session invalidated during response cannot replace cache', () async {
    await save(1, cache(now));
    final sub = c.listen(examSnapshotProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(examSnapshotProvider.future);
    adapter.gate = Completer<void>();
    final refresh = c.read(examSnapshotProvider.notifier).refresh();
    final failed = expectLater(refresh, throwsStateError);
    await adapter.entered.future;
    sessionCurrent = false;
    adapter.gate!.complete();
    await failed;
    expect(readExamCache(prefs, 1, 1, '20261')!.exams.single.id, 'cached');
  });
  test(
    'switching account while fetching never publishes old response',
    () async {
      await save(1, cache(now));
      await save(2, cache(now, course: '账号二课程'));
      final sub = c.listen(examSnapshotProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(examSnapshotProvider.future);
      adapter.gate = Completer<void>();
      final refresh = c.read(examSnapshotProvider.notifier).refresh();
      final failed = expectLater(refresh, throwsStateError);
      await adapter.entered.future;
      c.read(selectedRollcallAccountProvider.notifier).state = 2;
      expect(
        (await c.read(examSnapshotProvider.future)).exams.single.course,
        '账号二课程',
      );
      adapter.gate!.complete();
      await failed;
      expect(
        c.read(examSnapshotProvider).requireValue.exams.single.course,
        '账号二课程',
      );
      expect(readExamCache(prefs, 1, 1, '20261')!.exams.single.id, 'cached');
    },
  );
  test('new term ignores old cache and obtains current term once', () async {
    await save(1, cache(now, term: '20253'));
    final sub = c.listen(examSnapshotProvider, (_, _) {});
    addTearDown(sub.close);
    final result = await c.read(examSnapshotProvider.future);
    expect(result.term, '20261');
    expect(identities, 1);
  });
  test(
    'manual refresh joins a new-term cache miss while old data is retained',
    () async {
      await save(1, cache(now));
      final sub = c.listen(examSnapshotProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(examSnapshotProvider.future);
      now = DateTime(2027, 2, 16);
      adapter.gate = Completer<void>();
      c.invalidate(examSnapshotProvider);
      final pending = c.read(examSnapshotProvider.future);
      await adapter.entered.future;
      final manual = c.read(examSnapshotProvider.notifier).refresh();
      adapter.gate!.complete();
      expect((await pending).term, '20262');
      await manual;
      expect(identities, 1);
      expect(c.read(examSnapshotProvider).requireValue.term, '20262');
    },
  );
}
