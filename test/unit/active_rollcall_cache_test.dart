import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/rollcall/active_rollcall_cache.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

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
  Completer<List<RollcallItem>>? pending;
  @override
  Future<List<RollcallItem>> fetchActiveEnriched({
    CancelToken? cancelToken,
    Map<int, String> cachedNumberCodes = const {},
  }) async {
    calls++;
    return pending?.future ?? [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final observed = DateTime(2026, 10, 22, 8);
  final catalog = CourseCatalogSnapshot(
    fetchedAt: observed,
    rolesResolved: true,
    courses: [
      CatalogCourse(
        id: '42',
        title: 'Test',
        timetables: {
          4: [
            TimetableSlot(
              sequence: 1,
              start: DateTime(2000, 1, 3, 8),
              end: DateTime(2000, 1, 3, 9),
            ),
          ],
        },
      ),
    ],
  );
  final signed = RollcallItem.fromJson({
    'rollcall_id': 7,
    'course_id': 42,
    'course_title': 'Test',
    'is_number': true,
    'status': 'on_call_fine',
    'rollcall_status': 'on',
    'Cookie': 'never-cache',
    'data': 'never-cache-token',
  }).copyWith(numberCode: '0042');
  DiskCacheSnapshot snapshot() => DiskCacheSnapshot(
    fetchedAt: observed,
    items: cacheActiveRollcalls([signed], catalog, observed),
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'restore only inside exact class window; preserve signed state and zeros',
    () {
      final disk = snapshot();
      final restored = restoreActiveRollcalls(
        disk,
        DateTime(2026, 10, 22, 8, 30),
      ).single;
      expect(restored.isAnswered, isTrue);
      expect(restored.numberCode, '0042');
      expect(restored.courseId, '42');
      expect(disk.items.single.containsKey('Cookie'), isFalse);
      expect(disk.items.single.containsKey('data'), isFalse);
      expect(
        restoreActiveRollcalls(disk, DateTime(2026, 10, 22, 9, 25)),
        hasLength(1),
      );
      expect(
        restoreActiveRollcalls(disk, DateTime(2026, 10, 22, 9, 25, 1)),
        isEmpty,
      );
      expect(restoreActiveRollcalls(disk, DateTime(2026, 10, 29, 8)), isEmpty);
      expect(
        restoreActiveRollcalls(
          disk,
          observed.subtract(const Duration(days: 1)),
        ),
        isEmpty,
      );
    },
  );
  test(
    'pre-class window is 25 minutes; no guessed window without timetable',
    () {
      expect(
        cacheActiveRollcalls([signed], catalog, DateTime(2026, 10, 22, 7, 35)),
        hasLength(1),
      );
      expect(
        cacheActiveRollcalls([signed], catalog, DateTime(2026, 10, 22, 7, 34)),
        isEmpty,
      );
      expect(cacheActiveRollcalls([signed], null, observed), isEmpty);
      expect(
        cacheActiveRollcalls([signed], catalog, DateTime(2026, 10, 23, 8)),
        isEmpty,
      );
      expect(cacheActiveRollcalls([], catalog, observed), isEmpty);
    },
  );

  Future<void> seed() async {
    await CourseCatalogStore.write(1, catalog);
    await JsonDiskCache.writeList(
      'active_rollcalls_1_1',
      snapshot().items,
      fetchedAt: observed,
    );
  }

  ProviderContainer make(_Repo repo, DateTime Function() now) =>
      ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          activeRollcallClockProvider.overrideWithValue(now),
          rollcallRepositoryForProvider.overrideWith((ref, id) => repo),
        ],
      );
  test(
    'cached card appears before slow network; confirmed empty clears it and disk',
    () async {
      await seed();
      final repo = _Repo()..pending = Completer<List<RollcallItem>>();
      final container = make(
        repo,
        () => observed.add(const Duration(minutes: 10)),
      );
      addTearDown(container.dispose);
      final cached = await container.read(activeRollcallsProvider(null).future);
      expect(cached.single.isAnswered, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(activeRollcallsProvider(null)).isLoading, isTrue);
      expect(
        container
            .read(activeRollcallsProvider(null))
            .valueOrNull!
            .single
            .numberCode,
        '0042',
      );
      final updating = container
          .read(activeRollcallsProvider(null).notifier)
          .refresh();
      repo.pending!.complete([]);
      await updating;
      expect(
        container.read(activeRollcallsProvider(null)).requireValue,
        isEmpty,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        (await JsonDiskCache.readList('active_rollcalls_1_1'))!.items,
        isEmpty,
      );
      expect(repo.calls, 1);
    },
  );
  test('expired cache and another identity wait for real results', () async {
    await seed();
    for (final scope in [null, 2]) {
      final repo = _Repo()..pending = Completer<List<RollcallItem>>();
      final container = make(
        repo,
        () => scope == null ? observed.add(const Duration(hours: 2)) : observed,
      );
      final future = container.read(activeRollcallsProvider(scope).future);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(activeRollcallsProvider(scope)).hasValue, isFalse);
      repo.pending!.complete([]);
      expect(await future, isEmpty);
      container.dispose();
    }
  });
  test(
    'warm reentry checks join and throttle; leaving window hides form before confirmation',
    () async {
      await seed();
      var now = observed.add(const Duration(minutes: 10));
      final repo = _Repo()..pending = Completer<List<RollcallItem>>();
      final container = make(repo, () => now);
      addTearDown(container.dispose);
      await container.read(activeRollcallsProvider(null).future);
      final notifier = container.read(activeRollcallsProvider(null).notifier);
      await Future<void>.delayed(Duration.zero);
      final initial = notifier.refresh();
      repo.pending!.complete([signed]);
      await initial;
      for (var i = 0; i < 5; i++) {
        await notifier.ensureFreshOnAppear();
      }
      expect(repo.calls, 1);
      now = DateTime(2026, 10, 22, 9, 26);
      repo.pending = Completer<List<RollcallItem>>();
      final confirmation = notifier.ensureFreshOnAppear();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(activeRollcallsProvider(null)).valueOrNull,
        isEmpty,
      );
      expect(container.read(activeRollcallsProvider(null)).isLoading, isTrue);
      repo.pending!.complete([]);
      await confirmation;
      expect(repo.calls, 2);
    },
  );
  test('only fetched snapshots advance the list check time', () async {
    var now = observed;
    final repo = _Repo();
    final container = make(repo, () => now);
    addTearDown(container.dispose);
    await container.read(activeRollcallsProvider(null).future);
    final notifier = container.read(activeRollcallsProvider(null).notifier);
    expect(notifier.lastUpdatedAt, observed);
    now = now.add(const Duration(seconds: 30));
    notifier.applyMonitorItems([signed]); // Local automatic-answer feedback.
    expect(notifier.lastUpdatedAt, observed);
    expect(
      container
          .read(activeRollcallsProvider(null))
          .requireValue
          .single
          .isAnswered,
      isTrue,
    );
    notifier.applyMonitorItems([
      signed,
    ], fetchedAt: observed); // Repeated snapshot.
    expect(notifier.lastUpdatedAt, observed);
    now = now.add(const Duration(seconds: 90));
    notifier.applyMonitorItems([], fetchedAt: now);
    expect(notifier.lastUpdatedAt, now);
    expect(repo.calls, 1);
  });
}
