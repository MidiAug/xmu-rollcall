import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

class _AuthRepo extends Fake implements AuthRepository {}

class _RejectWrites extends InMemorySharedPreferencesStore {
  _RejectWrites() : super.withData({});
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

class _Auth extends AuthController {
  _Auth(int owner) : super(_AuthRepo()) {
    state = AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: owner, name: 'Test'),
    );
  }
}

RollcallItem _signed(int id, {bool expired = false}) => RollcallItem.fromJson({
  'rollcall_id': id,
  'course_id': 42,
  'course_title': 'Test',
  'is_number': true,
  'status': 'on_call_fine',
  'is_expired': expired,
});

/// Exercise real enrichment and provider persistence; only the network is fake.
class _Repo extends RollcallRepository {
  _Repo()
    : super(
        http: TronHttpClient(store: SecureStore.memory({})),
        identity: DeviceIdentity(SecureStore.memory({})),
      );
  List<RollcallItem> items = [_signed(7)];
  int lookups = 0;
  String? code = '0042';
  bool fail = false;
  @override
  Future<List<RollcallItem>> fetchActive({
    CancelToken? cancelToken,
    String? opId,
  }) async => items;
  @override
  Future<String?> fetchNumberCode(
    int id, {
    CancelToken? cancelToken,
    String? opId,
  }) async {
    lookups++;
    if (fail) throw StateError('offline');
    return code;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  ProviderContainer make(_Repo repo, {int owner = 1}) => ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => _Auth(owner)),
      rollcallRepositoryForProvider.overrideWith((ref, scope) => repo),
    ],
  );

  test('already answered activity still resolves its own code', () async {
    final repo = _Repo();
    final rows = await repo.fetchActiveEnriched();
    expect(rows.single.isAnswered, isTrue);
    expect(rows.single.numberCode, '0042');
    expect(repo.lookups, 1);
    repo.items = [_signed(8, expired: true)];
    expect((await repo.fetchActiveEnriched()).single.numberCode, isNull);
    expect(repo.lookups, 1);
  });

  test(
    'cached exact ID avoids lookups; another event in the same course does not inherit',
    () async {
      final repo = _Repo()..items = [_signed(7), _signed(8)];
      final rows = await repo.fetchActiveEnriched(
        cachedNumberCodes: {7: '0001'},
      );
      expect(rows.map((i) => i.numberCode), ['0001', '0042']);
      expect(repo.lookups, 1);
      repo.items = [_signed(7).copyWith(numberCode: '0002')];
      expect(
        (await repo.fetchActiveEnriched(
          cachedNumberCodes: {7: '0001'},
        )).single.numberCode,
        '0002',
      );
      expect(repo.lookups, 1);
    },
  );

  test(
    'provider restart restores persistent codes even without a timetable/card cache',
    () async {
      final repo = _Repo();
      final first = make(repo);
      expect(
        (await first.read(
          activeRollcallsProvider(null).future,
        )).single.numberCode,
        '0042',
      );
      await Future<void>.delayed(Duration.zero);
      expect((await JsonDiskCache.readList('number_codes_1_1'))!.items, [
        {'id': 7, 'code': '0042'},
      ]);
      expect(
        (await JsonDiskCache.readList('active_rollcalls_1_1'))!.items,
        isEmpty,
      );
      first.dispose();
      await (await SharedPreferences.getInstance()).reload();
      repo.fail = true;
      final restarted = make(repo);
      addTearDown(restarted.dispose);
      expect(
        (await restarted.read(
          activeRollcallsProvider(null).future,
        )).single.numberCode,
        '0042',
      );
      await restarted.read(activeRollcallsProvider(null).notifier).refresh();
      expect(repo.lookups, 1);
    },
  );
  test(
    'failed persistent write retries on refresh without querying the code again',
    () async {
      SharedPreferencesStorePlatform.instance = _RejectWrites();
      final repo = _Repo();
      final container = make(repo);
      addTearDown(container.dispose);
      await container.read(activeRollcallsProvider(null).future);
      await Future<void>.delayed(Duration.zero);
      SharedPreferencesStorePlatform.instance =
          InMemorySharedPreferencesStore.withData({});
      await container.read(activeRollcallsProvider(null).notifier).refresh();
      await Future<void>.delayed(Duration.zero);
      await (await SharedPreferences.getInstance()).reload();
      expect(
        (await JsonDiskCache.readList(
          'number_codes_1_1',
        ))!.items.single['code'],
        '0042',
      );
      expect(repo.lookups, 1);
    },
  );

  test(
    'cache separates owner and assist scope and expires after seven days',
    () async {
      await JsonDiskCache.writeList('number_codes_1_1', [
        {'id': 7, 'code': '0001'},
      ]);
      for (final scope in [null, 2]) {
        final repo = _Repo();
        final container = make(repo, owner: scope == null ? 3 : 1);
        expect(
          (await container.read(
            activeRollcallsProvider(scope).future,
          )).single.numberCode,
          '0042',
        );
        expect(repo.lookups, 1);
        await Future<void>.delayed(Duration.zero);
        container.dispose();
      }
      await JsonDiskCache.writeList(
        'number_codes_1_1',
        [
          {'id': 7, 'code': '0001'},
        ],
        fetchedAt: DateTime.now().subtract(const Duration(days: 8)),
      );
      final repo = _Repo();
      final container = make(repo);
      addTearDown(container.dispose);
      expect(
        (await container.read(
          activeRollcallsProvider(null).future,
        )).single.numberCode,
        '0042',
      );
      expect(repo.lookups, 1);
    },
  );

  test(
    'monitor signed snapshot resolves and persists; failures preserve signed state',
    () async {
      final repo = _Repo()..items = [];
      final container = make(repo);
      addTearDown(container.dispose);
      await container.read(activeRollcallsProvider(null).future);
      final notifier = container.read(activeRollcallsProvider(null).notifier);
      notifier.applyMonitorItems([_signed(7)]);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final row = container
          .read(activeRollcallsProvider(null))
          .requireValue
          .single;
      expect(row.numberCode, '0042');
      expect(row.isAnswered, isTrue);
      expect(
        (await JsonDiskCache.readList(
          'number_codes_1_1',
        ))!.items.single['code'],
        '0042',
      );
      repo.fail = true;
      notifier.applyMonitorItems([_signed(8)]);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(
        container
            .read(activeRollcallsProvider(null))
            .requireValue
            .single
            .isAnswered,
        isTrue,
      );
      expect(
        container
            .read(activeRollcallsProvider(null))
            .requireValue
            .single
            .numberCode,
        isNull,
      );
    },
  );
}
