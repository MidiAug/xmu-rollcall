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
    bool manual = false,
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
        restoreActiveRollcalls(disk, DateTime(2026, 10, 22, 9, 30)),
        hasLength(1),
      );
      expect(
        restoreActiveRollcalls(disk, DateTime(2026, 10, 22, 9, 30, 1)),
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
    'pre-class window is 30 minutes; no guessed window without timetable',
    () {
      expect(
        cacheActiveRollcalls([signed], catalog, DateTime(2026, 10, 22, 7, 30)),
        hasLength(1),
      );
      expect(
        cacheActiveRollcalls([signed], catalog, DateTime(2026, 10, 22, 7, 29)),
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
    'unchanged activity does not dirty history again; status changes do',
    () async {
      await CourseCatalogStore.write(1, catalog);
      final container = make(_Repo(), () => observed);
      addTearDown(container.dispose);
      await container.read(activeRollcallsProvider(null).future);
      final notifier = container.read(activeRollcallsProvider(null).notifier);
      notifier.applyMonitorItems([signed], fetchedAt: observed);
      expect(container.read(seenInProgressCourseIdsProvider), {'42'});
      container.read(seenInProgressCourseIdsProvider.notifier).state = {};
      notifier.applyMonitorItems([
        signed,
      ], fetchedAt: observed.add(const Duration(seconds: 20)));
      expect(container.read(seenInProgressCourseIdsProvider), isEmpty);
      notifier.applyMonitorItems([signed.copyWith(status: 'on_call_absence')]);
      expect(container.read(seenInProgressCourseIdsProvider), {'42'});
      container.read(seenInProgressCourseIdsProvider.notifier).state = {};
      notifier.patchItem(signed);
      expect(container.read(seenInProgressCourseIdsProvider), {'42'});
    },
  );
  test(
    'cached card appears without automatic HTTP; explicit refresh clears confirmed empty',
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
      expect(container.read(activeRollcallsProvider(null)).isLoading, isFalse);
      expect(repo.calls, 0);
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
  test(
    'expired scheduled and unknown timetable caches stay local until manual detection',
    () async {
      await seed();
      for (final scope in [null, 2]) {
        final repo = _Repo()..pending = Completer<List<RollcallItem>>();
        final container = make(
          repo,
          () =>
              scope == null ? observed.add(const Duration(hours: 2)) : observed,
        );
        final future = container.read(activeRollcallsProvider(scope).future);
        await Future<void>.delayed(Duration.zero);
        if (scope == null) {
          expect(await future, isEmpty);
          expect(repo.calls, 0);
        } else {
          expect(
            container.read(activeRollcallsProvider(scope)).hasValue,
            isTrue,
          );
        }
        repo.pending!.complete([]);
        expect(await future, isEmpty);
        container.dispose();
      }
    },
  );
  test(
    'scheduled reentry never queries; expired form hides locally; manual pull still queries',
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
      now = now.add(const Duration(seconds: 29));
      await notifier.ensureFreshOnAppear();
      expect(repo.calls, 1);
      now = now.add(const Duration(seconds: 1));
      repo.pending = null;
      await notifier.ensureFreshOnAppear();
      expect(repo.calls, 1);
      now = DateTime(2026, 10, 22, 9, 31);
      repo.pending = Completer<List<RollcallItem>>();
      final confirmation = notifier.ensureFreshOnAppear();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(activeRollcallsProvider(null)).valueOrNull,
        isEmpty,
      );
      expect(container.read(activeRollcallsProvider(null)).isLoading, isFalse);
      await confirmation;
      expect(repo.calls, 1);
      final manual = notifier.refresh();
      repo.pending!.complete([]);
      await manual;
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
    expect(notifier.lastUpdatedAt, isNull);
    await notifier.refresh(manual: true);
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
