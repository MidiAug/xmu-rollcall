import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_providers.dart';
import 'package:xmu_rollcall/features/campus_card/electricity_provider.dart';
import '../fixtures/campus_card_fixture.dart';

class _Client extends ElectricityClient {
  _Client(this.query);
  final Future<ElectricReading> Function(CardElectricRoom) query;
  @override
  Future<ElectricReading> read(CardElectricRoom room) => query(room);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final selection = StateProvider<BrowserIdentity>(
    (ref) => (ownerId: 1, userId: 1, assistId: null),
  );
  Future<void> seed({bool cached = false}) async {
    final room = electricRoomFixture('0301'),
        common = electricRoomFixture('0300');
    SharedPreferences.setMockInitialValues({
      'campus_card_v1_1_1': jsonEncode({
        'card': cardFixture().toJson(),
        'fetchedAt': DateTime.now().toIso8601String(),
      }),
      'campus_card_rooms_v1_1_1': jsonEncode({
        'personal': room.toJson(),
        'shared': common.toJson(),
      }),
      if (cached)
        'campus_electricity_v1_1_1': jsonEncode({
          'personal': ElectricReading(
            room: room,
            balance: 10,
            kwh: 20,
            checkedAt: DateTime.now(),
          ).toJson(),
          'shared': ElectricReading(
            room: common,
            balance: 30,
            kwh: 60,
            checkedAt: DateTime.now(),
          ).toJson(),
        }),
    });
  }

  test(
    'opening automatically queries both saved rooms and caches scoped readings',
    () async {
      await seed();
      final calls = <String>[];
      final c = ProviderContainer(
        overrides: [
          browserIdentityProvider.overrideWith((ref) => ref.watch(selection)),
          electricityClientFactoryProvider.overrideWithValue(
            () => _Client((room) async {
              calls.add(room.id);
              return ElectricReading(
                room: room,
                balance: 42.5,
                kwh: 85,
                checkedAt: DateTime.now(),
              );
            }),
          ),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(electricityProvider, (_, _) {});
      addTearDown(sub.close);
      final value = await c.read(electricityProvider.future);
      expect(value, hasLength(2));
      expect(calls, ['0301', '0300']);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'campus_electricity_v1_1_1',
        ),
        isNotNull,
      );
    },
  );
  test(
    'fresh cache avoids requests; failed update retains all previous readings and dates',
    () async {
      await seed(cached: true);
      var calls = 0;
      final c = ProviderContainer(
        overrides: [
          browserIdentityProvider.overrideWith((ref) => ref.watch(selection)),
          electricityClientFactoryProvider.overrideWithValue(
            () => _Client((room) async {
              calls++;
              throw const FormatException('查询失败');
            }),
          ),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(electricityProvider, (_, _) {});
      addTearDown(sub.close);
      final first = await c.read(electricityProvider.future);
      expect(calls, 0);
      await c.read(electricityProvider.notifier).refresh();
      expect(
        c
            .read(electricityProvider)
            .requireValue[CardElectricRoomKind.personal]!
            .checkedAt,
        first[CardElectricRoomKind.personal]!.checkedAt,
      );
      expect(
        c
            .read(electricityProvider)
            .requireValue[CardElectricRoomKind.shared]!
            .balance,
        30,
      );
      expect(c.read(electricityProvider.notifier).warning, '查询失败');
      await c.read(electricityProvider.notifier).refresh();
      expect(calls, 1);
    },
  );
  test(
    'switching identity during a query never saves or publishes the old room',
    () async {
      await seed();
      final pending = Completer<ElectricReading>();
      var began = false;
      final c = ProviderContainer(
        overrides: [
          browserIdentityProvider.overrideWith((ref) => ref.watch(selection)),
          electricityClientFactoryProvider.overrideWithValue(
            () => _Client((room) async {
              began = true;
              return pending.future;
            }),
          ),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(electricityProvider, (_, _) {});
      addTearDown(sub.close);
      while (!began) {
        await Future<void>.delayed(Duration.zero);
      }
      c.read(selection.notifier).state = (ownerId: 1, userId: 2, assistId: 2);
      expect(await c.read(electricityProvider.future), isEmpty);
      pending.complete(
        ElectricReading(
          room: electricRoomFixture('0301'),
          balance: 99,
          kwh: 200,
          checkedAt: DateTime.now(),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'campus_electricity_v1_1_1',
        ),
        isNull,
      );
      expect(c.read(electricityProvider).requireValue, isEmpty);
    },
  );
}
