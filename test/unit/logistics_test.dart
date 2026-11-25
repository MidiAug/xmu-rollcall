import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/remote_course_cache.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/logistics/logistics_client.dart';
import 'package:xmu_rollcall/features/logistics/logistics_provider.dart';
import '../fixtures/logistics_fixture.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  String account = 'fixture';
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(o);
    if (o.uri.host == 'ids.xmu.edu.cn') {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            'https://xdhq.xmu.edu.cn/account/login?userinfo=fixture',
          ],
        },
      );
    }
    final data = switch (o.uri.path) {
      '/api/auth/login/auto' => 'fixture-token',
      '/api/auth/user/info' => {'account': account},
      '/api/repair/oneNetPublish/myList' ||
      '/api/manager/systemPersonalWait/listMessage' => {'total': 0, 'rows': []},
      _ => throw StateError('Unexpected request: ${o.uri.path}'),
    };
    return ResponseBody.fromString(
      logisticsEncrypt(
        jsonEncode({'status': 'success', 'errorCode': 0, 'data': data}),
      ),
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}

final _identity = StateProvider<BrowserIdentity>(
  (ref) => (ownerId: 1, userId: 1, assistId: null),
);
ProviderContainer _container(LogisticsFixtureClient Function() factory) =>
    ProviderContainer(
      overrides: [
        browserIdentityProvider.overrideWith((ref) => ref.watch(_identity)),
        academicIdentityResolverProvider.overrideWithValue(
          (uid) async => AcademicIdentity(
            username: 'fixture',
            isCurrent: () async => true,
          ),
        ),
        logisticsClientFactoryProvider.overrideWithValue(factory),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('official AES response vector and damaged envelope', () {
    // Independent Node crypto AES/CBC/PKCS7 vector.
    const encoded =
        'KCZ+7o41+kywq/8vTPqM4n2Y5/W7Lr9uSPXTBA4DB/zhAJe3tBUNCfWO041drWM1PZ7v6ja+0TdwhdvJVNFHgg==';
    expect(logisticsDecode(encoded)['data'], {'total': 0, 'rows': []});
    expect(() => logisticsDecode('broken'), throwsFormatException);
    expect(
      () => LogisticsRepair({...logisticsRepairFixture(1), 'id': ''}),
      throwsFormatException,
    );
  });
  test(
    'CAS callback, auth headers and current-account check precede business reads',
    () async {
      final adapter = _Adapter();
      final client = LogisticsClient(
        dio: Dio()..httpClientAdapter = adapter,
        limiter: RateLimiter(minInterval: Duration.zero),
      );
      await client.connect(username: 'fixture');
      expect(await client.repairs(1), {'total': 0, 'rows': []});
      expect(await client.messages(), {'total': 0, 'rows': []});
      expect(adapter.calls.length, 5);
      expect(adapter.calls.last.headers['TokenKey'], 'fixture-token');
      expect(adapter.calls.last.headers.containsKey('Authorization'), isFalse);
      adapter.account = 'other-account';
      final other = LogisticsClient(
        dio: Dio()..httpClientAdapter = adapter,
        limiter: RateLimiter(minInterval: Duration.zero),
      );
      await expectLater(
        other.connect(username: 'fixture'),
        throwsFormatException,
      );
      expect(adapter.calls.last.uri.path, '/api/auth/user/info');
    },
  );
  for (final total in [0, 21, 111]) {
    test(
      'batch pagination $total never requests individual repair details',
      () async {
        final client = LogisticsFixtureClient(total: total);
        final container = _container(() => client);
        addTearDown(container.dispose);
        final sub = container.listen(logisticsProvider, (_, _) {});
        addTearDown(sub.close);
        await container.read(logisticsProvider.future);
        final notifier = container.read(logisticsProvider.notifier);
        while (container.read(logisticsProvider).requireValue.repairs.length <
            total) {
          await notifier.refresh(more: true);
        }
        expect(
          container.read(logisticsProvider).requireValue.repairs.length,
          total,
        );
        expect(client.pages, [
          for (var i = 1; i <= (total == 0 ? 1 : (total / 20).ceil()); i++) i,
        ]);
        expect(client.messageRequests, 1);
      },
    );
  }
  test(
    'failed update preserves cache time and does not replace existing data',
    () async {
      final identity = (ownerId: 1, userId: 1, assistId: null);
      final stamp = DateTime.now();
      final cached = LogisticsSnapshot(
        repairs: [LogisticsRepair(logisticsRepairFixture(0))],
        messages: [],
        total: 1,
        page: 1,
        fetchedAt: stamp,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        logisticsCacheKey(identity),
        jsonEncode(cached.toJson()),
      );
      final client = LogisticsFixtureClient()..fail = true;
      final container = _container(() => client);
      addTearDown(container.dispose);
      final sub = container.listen(logisticsProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(logisticsProvider.future);
      expect(client.pages, isEmpty);
      await container.read(logisticsProvider.notifier).refresh();
      expect(container.read(logisticsProvider).requireValue.fetchedAt, stamp);
      expect(container.read(logisticsProvider.notifier).warning, '网络暂不可用');
      expect(
        jsonDecode(prefs.getString(logisticsCacheKey(identity))!)['fetchedAt'],
        stamp.toIso8601String(),
      );
      await clearRemoteCourseCache();
      expect(prefs.getString(logisticsCacheKey(identity)), isNull);
    },
  );
  test(
    'in-flight previous identity cannot populate the next identity or its disk cache',
    () async {
      final delayed = LogisticsFixtureClient()..pending = Completer<void>();
      final next = LogisticsFixtureClient(total: 0);
      var count = 0;
      final container = _container(() => count++ == 0 ? delayed : next);
      addTearDown(container.dispose);
      final sub = container.listen(logisticsProvider, (_, _) {});
      addTearDown(sub.close);
      final old = container.read(logisticsProvider.future);
      while (delayed.pages.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      container.read(_identity.notifier).state = (
        ownerId: 1,
        userId: 2,
        assistId: 2,
      );
      final newer = container.read(logisticsProvider.future);
      delayed.pending!.complete();
      expect((await old).repairs, isEmpty);
      expect((await newer).repairs, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('logistics_v1_1_1'), isNull);
      expect(container.read(logisticsProvider).requireValue.total, 0);
    },
  );
}
