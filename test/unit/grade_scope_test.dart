import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/grades/grade_models.dart';
import 'package:xmu_rollcall/features/grades/grade_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import 'package:xmu_rollcall/features/schedule/academic_sync.dart';
import 'package:xmu_rollcall/features/grades/academic_grade_reader.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'A'),
    );
  }
}

class _Client extends AcademicGradeReader {
  _Client(SecureStore store) : super(AcademicSession(store: store));
  final entered = Completer<void>();
  final result = Completer<AcademicGradeResult>();
  String? receivedPassword;
  bool? receivedRecent;
  @override
  Future<AcademicGradeResult> fetch(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    bool recent = false,
  }) {
    receivedPassword = password;
    receivedRecent = recent;
    entered.complete();
    return result.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final uid in [1, 2]) {
    test(
      'mid-semester account $uid reuses old cache without academic access; manual refresh remains available',
      () async {
        final now = DateTime(2026, 10, 31);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          gradeCacheKey(1, uid),
          jsonEncode(
            GradeSnapshot(
              at: now.subtract(const Duration(days: 40)),
              term: '20261',
              records: [
                GradeRecord({'WID': 'cached', 'KCM': '缓存课程'}),
              ],
            ).toJson(),
          ),
        );
        final store = SecureStore.memory({SecureStore.keyUserId: '1'});
        final client = _Client(store);
        var identities = 0;
        final c = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith((ref) => _Auth()),
            assistControllerProvider.overrideWith(
              (ref) => AssistController(
                ref,
                bootstrap: false,
                initial: AssistUiState(
                  ready: true,
                  identities: [
                    AssistIdentity(
                      userId: 2,
                      kind: AssistCredentialKind.account,
                      displayName: 'B',
                      importedAt: DateTime(2026),
                    ),
                  ],
                ),
              ),
            ),
            academicIdentityResolverProvider.overrideWithValue((id) async {
              identities++;
              return AcademicIdentity(isCurrent: () async => true);
            }),
            secureStoreProvider.overrideWithValue(store),
            gradeClockProvider.overrideWithValue(() => now),
            gradeReaderProvider.overrideWithValue(() => client),
          ],
        );
        addTearDown(c.dispose);
        if (uid == 2) {
          c.read(selectedRollcallAccountProvider.notifier).state = 2;
        }
        final sub = c.listen(gradeSnapshotProvider, (_, _) {});
        addTearDown(sub.close);
        expect(
          (await c.read(gradeSnapshotProvider.future)).records.single.id,
          'cached',
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(identities, 0);
        expect(client.entered.isCompleted, isFalse);
        final manual = c.read(gradeSnapshotProvider.notifier).refresh();
        await client.entered.future;
        client.result.complete(
          const AcademicGradeResult(
            rows: [],
            replacedTerms: {},
            complete: true,
          ),
        );
        await manual;
        expect(identities, 1);
      },
    );
  }

  for (final uid in [1, 2]) {
    for (final fails in [false, true]) {
      test(
        'stale cached grades show before a slow refresh, account=$uid failure=$fails',
        () async {
          final now = DateTime(2027, 1, 11);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            gradeCacheKey(1, uid),
            jsonEncode(
              GradeSnapshot(
                at: now.subtract(const Duration(days: 2)),
                term: '20261',
                records: [
                  GradeRecord({'WID': 'cached', 'KCM': '缓存课程'}),
                ],
              ).toJson(),
            ),
          );
          final store = SecureStore.memory({SecureStore.keyUserId: '1'});
          final client = _Client(store);
          final c = ProviderContainer(
            overrides: [
              authControllerProvider.overrideWith((ref) => _Auth()),
              assistControllerProvider.overrideWith(
                (ref) => AssistController(
                  ref,
                  bootstrap: false,
                  initial: AssistUiState(
                    ready: true,
                    identities: [
                      AssistIdentity(
                        userId: 2,
                        kind: AssistCredentialKind.account,
                        displayName: 'B',
                        importedAt: DateTime(2026),
                      ),
                    ],
                  ),
                ),
              ),
              academicIdentityResolverProvider.overrideWithValue(
                (id) async => AcademicIdentity(isCurrent: () async => true),
              ),
              secureStoreProvider.overrideWithValue(store),
              gradeClockProvider.overrideWithValue(() => now),
              academicSyncProvider.overrideWith((ref) => AcademicSync(store)),
              gradeReaderProvider.overrideWithValue(() => client),
            ],
          );
          addTearDown(c.dispose);
          if (uid == 2) {
            c.read(selectedRollcallAccountProvider.notifier).state = 2;
          }
          final sub = c.listen(gradeSnapshotProvider, (_, _) {});
          addTearDown(sub.close);
          final cached = await c.read(gradeSnapshotProvider.future);
          expect(cached.records.single.id, 'cached');
          await client.entered.future;
          expect(
            c.read(gradeSnapshotProvider).requireValue.records.single.id,
            'cached',
          );
          expect(c.read(gradeSnapshotProvider).isLoading, isFalse);
          final refresh = c.read(gradeSnapshotProvider.notifier).refresh();
          if (fails) {
            client.result.completeError(StateError('offline'));
            await expectLater(refresh, throwsStateError);
            await Future<void>.delayed(Duration.zero);
            expect(
              c.read(gradeSnapshotProvider).requireValue.records.single.id,
              'cached',
            );
            expect(
              c.read(gradeSnapshotProvider.notifier).warning,
              contains('本地缓存'),
            );
          } else {
            client.result.complete(
              const AcademicGradeResult(
                rows: [
                  {'WID': 'new', 'KCM': '新成绩'},
                ],
                replacedTerms: {},
                complete: true,
              ),
            );
            await refresh;
            expect(
              c.read(gradeSnapshotProvider).requireValue.records.single.id,
              'new',
            );
            expect(
              jsonDecode(
                prefs.getString(gradeCacheKey(1, uid))!,
              )['records'][0]['WID'],
              'new',
            );
          }
        },
      );
    }
  }
  test(
    'legacy classification upgrades in release season while cached grades remain readable',
    () async {
      final at = DateTime(2027, 1, 11);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        gradeCacheKey(1, 1),
        jsonEncode({
          'at': at.toIso8601String(),
          'term': '20261',
          'records': [
            {'WID': 'old', 'XF': 2, 'XFJD': 4},
          ],
        }),
      );
      final store = SecureStore.memory({SecureStore.keyUserId: '1'});
      final client = _Client(store);
      final c = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          secureStoreProvider.overrideWithValue(store),
          gradeClockProvider.overrideWithValue(() => at),
          academicSyncProvider.overrideWith((ref) => AcademicSync(store)),
          gradeReaderProvider.overrideWithValue(() => client),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(gradeSnapshotProvider, (_, _) {});
      addTearDown(sub.close);
      await client.entered.future;
      final refresh = c.read(gradeSnapshotProvider.notifier).refresh();
      expect(client.receivedRecent, isFalse);
      client.result.complete(
        AcademicGradeResult(
          rows: [
            {'WID': 'new', 'XF': 2, 'XFJD': 4, 'DJCJLXDM': '100'},
          ],
          replacedTerms: <String>{},
        ),
      );
      await refresh;
      final snapshot = c.read(gradeSnapshotProvider).requireValue;
      expect(snapshot.version, 2);
      expect(snapshot.records.single.id, 'new');
      expect(jsonDecode(prefs.getString(gradeCacheKey(1, 1))!)['version'], 2);
    },
  );
  test(
    'graduate full refresh replaces stale rows rather than treating empty grades as failure',
    () async {
      final now = DateTime(2027, 1, 11);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        gradeCacheKey(1, 1),
        jsonEncode(
          GradeSnapshot(
            at: now.subtract(const Duration(days: 2)),
            term: '20261',
            education: 'graduate',
            records: [
              GradeRecord({'WID': 'old', 'KCM': 'withdrawn'}),
            ],
          ).toJson(),
        ),
      );
      final store = SecureStore.memory({SecureStore.keyUserId: '1'});
      final client = _Client(store);
      final c = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          secureStoreProvider.overrideWithValue(store),
          gradeClockProvider.overrideWithValue(() => now),
          academicSyncProvider.overrideWith((ref) => AcademicSync(store)),
          gradeReaderProvider.overrideWithValue(() => client),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(gradeSnapshotProvider, (_, _) {});
      addTearDown(sub.close);
      await client.entered.future;
      final refresh = c.read(gradeSnapshotProvider.notifier).refresh();
      expect(client.receivedRecent, isTrue);
      client.result.complete(
        const AcademicGradeResult(
          rows: [],
          replacedTerms: {},
          education: 'graduate',
          complete: true,
        ),
      );
      await refresh;
      final result = c.read(gradeSnapshotProvider).requireValue;
      expect(result.records, isEmpty);
      expect(result.education, 'graduate');
      expect(
        jsonDecode(prefs.getString(gradeCacheKey(1, 1))!)['education'],
        'graduate',
      );
    },
  );
  test(
    'fresh account caches load separately without a network client',
    () async {
      final at = DateTime(2026, 10, 28);
      final prefs = await SharedPreferences.getInstance();
      for (final id in [1, 2]) {
        await prefs.setString(
          gradeCacheKey(1, id),
          jsonEncode(
            GradeSnapshot(
              at: at,
              term: '20261',
              records: [
                GradeRecord({'WID': '$id', 'KCM': 'account$id'}),
              ],
            ).toJson(),
          ),
        );
      }
      final c = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(
              ref,
              bootstrap: false,
              initial: AssistUiState(
                ready: true,
                identities: [
                  AssistIdentity(
                    userId: 2,
                    kind: AssistCredentialKind.account,
                    displayName: 'B',
                    importedAt: DateTime(2026),
                  ),
                ],
              ),
            ),
          ),
          gradeClockProvider.overrideWithValue(() => at),
          gradeReaderProvider.overrideWithValue(
            () => throw StateError('no network'),
          ),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(gradeSnapshotProvider, (_, _) {});
      addTearDown(sub.close);
      expect(
        (await c.read(gradeSnapshotProvider.future)).records.single.title,
        'account1',
      );
      c.read(selectedRollcallAccountProvider.notifier).state = 2;
      expect(
        (await c.read(gradeSnapshotProvider.future)).records.single.title,
        'account2',
      );
    },
  );
  test(
    'switch while grades pending blocks cache publication and keeps target credentials',
    () async {
      final at = DateTime(2026, 10, 28);
      final store = SecureStore.memory({
        SecureStore.keyUserId: '1',
        SecureStore.keyOwnerPassword: 'owner-secret',
      });
      final client = _Client(store);
      final c = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(
              ref,
              bootstrap: false,
              initial: AssistUiState(
                ready: true,
                identities: [
                  AssistIdentity(
                    userId: 2,
                    kind: AssistCredentialKind.account,
                    displayName: 'B',
                    importedAt: DateTime(2026),
                  ),
                ],
              ),
            ),
          ),
          secureStoreProvider.overrideWithValue(store),
          gradeClockProvider.overrideWithValue(() => at),
          academicIdentityResolverProvider.overrideWithValue(
            (uid) async => uid == 2
                ? AcademicIdentity(
                    username: 'sample2',
                    password: 'assist-secret',
                    isCurrent: () async => true,
                  )
                : null,
          ),
          gradeReaderProvider.overrideWithValue(() => client),
        ],
      );
      addTearDown(c.dispose);
      c.read(selectedRollcallAccountProvider.notifier).state = 2;
      final sub = c.listen(gradeSnapshotProvider, (_, _) {});
      addTearDown(sub.close);
      await client.entered.future;
      expect(client.receivedPassword, 'assist-secret');
      expect(client.receivedRecent, isFalse);
      // New account already has local data, so no second client is created.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        gradeCacheKey(1, 1),
        jsonEncode(GradeSnapshot(at: at, term: '20261', records: []).toJson()),
      );
      c.read(selectedRollcallAccountProvider.notifier).state = null;
      await c.read(gradeSnapshotProvider.future);
      client.result.complete(
        AcademicGradeResult(
          rows: [
            {'WID': 'private', 'KCM': 'assist grade'},
          ],
          replacedTerms: <String>{},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(prefs.getString(gradeCacheKey(1, 2)), isNull);
      expect(c.read(gradeSnapshotProvider).requireValue.records, isEmpty);
    },
  );
}
