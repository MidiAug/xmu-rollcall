import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/lectures/lecture_provider.dart';
import '../fixtures/lecture_fixture.dart';

class _Held extends LectureFixtureClient {
  final pending = Completer<LecturePage>();
  bool started = false;
  @override
  Future<LecturePage> attended({int page = 1}) {
    started = true;
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const identity = (ownerId: 1, userId: 1, assistId: null);
  final selected = StateProvider<BrowserIdentity>((ref) => identity);
  ProviderContainer container(LectureFixtureClient client) => ProviderContainer(
    overrides: [
      browserIdentityProvider.overrideWith((ref) => ref.watch(selected)),
      secureStoreProvider.overrideWithValue(
        SecureStore.memory({lectureSessionKey(identity): 'fixture-session'}),
      ),
      lectureClientFactoryProvider.overrideWithValue(() => client),
      academicIdentityResolverProvider.overrideWithValue(
        (uid) async => AcademicIdentity(
          username: 'fixture-student',
          isCurrent: () async => true,
        ),
      ),
    ],
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'one first page per source, cache contains no credential, failed refresh preserves it',
    () async {
      final client = LectureFixtureClient();
      final scope = container(client);
      final sub = scope.listen(lectureProvider, (_, _) {});
      final first = await scope.read(lectureProvider.future);
      expect(client.lists, 1);

      final stamp = scope.read(lectureProvider.notifier).fetchedAt;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(lectureCacheKey(identity))!;
      expect(raw, isNot(contains('fixture-session')));
      // Reopen with the existing cache, so manual refresh has not just been attempted.
      sub.close();
      scope.dispose();
      final later = container(client);
      addTearDown(later.dispose);
      final laterSub = later.listen(lectureProvider, (_, _) {});
      addTearDown(laterSub.close);
      expect((await later.read(lectureProvider.future)).successCount, 15);
      expect(client.lists, 1);
      client.fail = true;
      await later.read(lectureProvider.notifier).refresh();
      expect(later.read(lectureProvider).requireValue.total, first.total);
      expect(later.read(lectureProvider.notifier).fetchedAt, stamp);
      expect(later.read(lectureProvider.notifier).warning, '测试更新失败');
      expect(prefs.getString(lectureCacheKey(identity)), raw);
      await later.read(lectureProvider.notifier).refresh();
      expect(client.lists, 2);
    },
  );
  test(
    'switching identity discards an old account response without writing a cache',
    () async {
      final client = _Held();
      final c = container(client);
      addTearDown(c.dispose);
      final sub = c.listen(lectureProvider, (_, _) {});
      addTearDown(sub.close);
      while (!client.started) {
        await Future<void>.delayed(Duration.zero);
      }
      c.read(selected.notifier).state = (ownerId: 1, userId: 2, assistId: 2);
      await expectLater(
        c.read(lectureProvider.future),
        throwsA(isA<LectureLoginRequired>()),
      );
      client.pending.complete(
        LecturePage([LectureEntry.fromJson(lectureFixture())], 1, null),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        (await SharedPreferences.getInstance()).getString(
          lectureCacheKey(identity),
        ),
        isNull,
      );
      expect(jsonEncode(c.read(lectureProvider).valueOrNull), 'null');
    },
  );
}
