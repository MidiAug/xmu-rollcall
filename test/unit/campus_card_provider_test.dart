import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/remote_course_cache.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_providers.dart';
import '../fixtures/campus_card_fixture.dart';

final selection = StateProvider<BrowserIdentity>(
  (ref) => (ownerId: 1, userId: 1, assistId: null),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  ProviderContainer container(CampusCardFixtureClient Function() factory) =>
      ProviderContainer(
        overrides: [
          browserIdentityProvider.overrideWith((ref) => ref.watch(selection)),
          campusCardClientFactoryProvider.overrideWithValue(factory),
          academicIdentityResolverProvider.overrideWithValue(
            (uid) async => AcademicIdentity(
              username: '20260000000001',
              isCurrent: () async => true,
            ),
          ),
        ],
      );
  Future<void> seed(DateTime stamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'campus_card_v1_1_1',
      jsonEncode({
        'card': cardFixture().toJson(),
        'fetchedAt': stamp.toIso8601String(),
      }),
    );
  }

  test(
    'fresh cache is shown without a request and manual failure preserves it',
    () async {
      final stamp = DateTime.now();
      await seed(stamp);
      final client = CampusCardFixtureClient()..fail = true;
      final c = container(() => client);
      addTearDown(c.dispose);
      final sub = c.listen(campusCardInfoProvider, (_, _) {});
      addTearDown(sub.close);
      expect((await c.read(campusCardInfoProvider.future)).balanceCents, 12850);
      expect(client.fetchCount, 0);
      final notifier = c.read(campusCardInfoProvider.notifier);
      await notifier.refresh();
      expect(c.read(campusCardInfoProvider).requireValue.balanceCents, 12850);
      expect(notifier.fetchedAt, stamp);
      expect(notifier.warning, '网络暂不可用');
      final before = client.fetchCount;
      await notifier.refresh();
      expect(client.fetchCount, before);
      final prefs = await SharedPreferences.getInstance();
      expect(
        cardMap(prefs.getString('campus_card_v1_1_1'))['fetchedAt'],
        stamp.toIso8601String(),
      );
    },
  );
  test(
    'stale cache starts one opening check; cache-only directory never queries',
    () async {
      await seed(DateTime.now().subtract(const Duration(hours: 1)));
      final client = CampusCardFixtureClient()..fail = true;
      final c = container(() => client);
      addTearDown(c.dispose);
      expect(
        (await c.read(campusCardCachedInfoProvider.future))?.account,
        '900001',
      );
      expect(client.fetchCount, 0);
      final sub = c.listen(campusCardInfoProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(campusCardInfoProvider.future);
      while (client.fetchCount == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(Duration.zero);
      expect(client.fetchCount, 1);
      expect(c.read(campusCardInfoProvider).valueOrNull?.account, '900001');
    },
  );
  test(
    'switching identity during connection cannot dispatch a write or overwrite cache',
    () async {
      await seed(DateTime.now());
      final previous = CampusCardFixtureClient()
        ..pending = Completer<CampusCardInfo>();
      final next = CampusCardFixtureClient()
        ..value = cardFixture(account: '900002');
      var count = 0;
      final c = container(() => count++ == 0 ? previous : next);
      addTearDown(c.dispose);
      final sub = c.listen(campusCardInfoProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(campusCardInfoProvider.future);
      final old = c
          .read(campusCardInfoProvider.notifier)
          .run((client) => client.recharge(1000));
      final assertion = expectLater(old, throwsStateError);
      while (previous.fetchCount == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      c.read(selection.notifier).state = (ownerId: 1, userId: 2, assistId: 2);
      await c.read(campusCardInfoProvider.future);
      previous.pending!.complete(cardFixture());
      await assertion;
      expect(previous.writes, isEmpty);
      expect(next.writes, isEmpty);
      expect(c.read(campusCardInfoProvider).requireValue.account, '900002');
      final prefs = await SharedPreferences.getInstance();
      expect(
        cardMap(
          cardMap(prefs.getString('campus_card_v1_1_1'))['card'],
        )['account'],
        '900001',
      );
      expect(
        cardMap(
          cardMap(prefs.getString('campus_card_v1_1_2'))['card'],
        )['account'],
        '900002',
      );
    },
  );
  test(
    'clear action removes new and legacy card caches while keeping handwritten data',
    () async {
      SharedPreferences.setMockInitialValues({
        'campus_card_v1_1_1': 'snapshot',
        'life_v1_1': 'old',
        'personal_meeting': 'keep',
      });
      await clearRemoteCourseCache();
      final p = await SharedPreferences.getInstance();
      expect(p.getString('campus_card_v1_1_1'), isNull);
      expect(p.getString('life_v1_1'), isNull);
      expect(p.getString('personal_meeting'), 'keep');
    },
  );
}
