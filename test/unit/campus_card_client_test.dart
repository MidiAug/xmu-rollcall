import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_client.dart';
import '../fixtures/campus_card_fixture.dart';

class _Wire implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  String studentNo = '20260000000001';
  Object? Function(RequestOptions)? reply;
  Completer<void>? holdPayment;
  String publicKey = '';
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(o);
    if (o.uri.path == '/cassyno/index') {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['/Error/PError'],
          'set-cookie': ['ASP.NET_SessionId=fixture; Path=/; Secure; HttpOnly'],
        },
      );
    }
    if (o.uri.path == '/Error/PError') {
      return ResponseBody.fromString('<html></html>', 200);
    }
    if (o.uri.path == '/Page/Page') {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['/PPage/ComePage'],
        },
      );
    }
    if (o.uri.path == '/PPage/ComePage') {
      return ResponseBody.fromString(
        "var account1 = '900001'; var timenow = '2026/11/25 12:00:00'; function SaveOrder(){mm.keyvalue='fixture-grant';mm.sign='fixture-sign';}",
        200,
      );
    }
    if (o.uri.path == '/User/Account_Pay') await holdPayment?.future;
    final supplied = reply?.call(o);
    final data =
        supplied ??
        switch (o.uri.path) {
          '/User/GetCardInfo' => {
            'IsSucceed': false,
            'Msg': jsonEncode({
              'query_card': {
                'retcode': 0,
                'card': [cardFixtureRow(studentNo: studentNo)],
              },
            }),
          },
          '/User/GetCardAccInfo' => {
            'IsSucceed': false,
            'Msg': jsonEncode({
              'query_accinfo': {'retcode': 0, 'accinfo': []},
            }),
          },
          '/Report/GetPersonTrjn' || '/Report/GetMyBill' => {
            'issucceed': false,
            'total': 0,
            'rows': [
              for (var i = 0; i < 15; i++)
                {
                  'MERCNAME': '食堂',
                  'TRANNAME': '消费',
                  'TRANAMT': -12.50,
                  'CARDBAL': 128.50,
                  'OCCTIME': '2026-11-25 12:00:00',
                  'JNUM': i,
                },
            ],
          },
          '/Tsm/GetRiceWate' => {
            'IsSucceed': true,
            'Msg': jsonEncode({
              'query_mf_xfls': {
                'retcode': 0,
                'nextpage': 0,
                'pagesize': 1,
                'mfxfls': [
                  {
                    'mercname': '测试米饭商户',
                    'tradedate': 20261125,
                    'tradetime': 120001,
                    'tranamt': 0.5,
                  },
                ],
              },
            }),
          },
          '/report/getamtBypaytype' => [
            {'code': 'food', 'name': '餐饮', 'value': 0},
          ],
          '/Common/GetRsaKey' => {
            'IsSucceed': true,
            'Msg': 'fixture-key',
            'Obj': publicKey,
          },
          '/User/LostCard' ||
          '/User/MendQueryPasswd' ||
          '/GetPasswd/SendSMS' ||
          '/T_Json/UpdataColsByJson' => {'IsSucceed': true, 'Msg': '成功'},
          '/User/Account_Pay' => {
            'IsSucceed': true,
            'Obj': 'get',
            'Msg': 'https://openapi.alipay.com/gateway.do?sign=fixture',
            'OrderID': 'fixture-order',
          },
          '/Tsm/TsmCommon' => {
            'Msg': jsonEncode({
              'query_elec_roominfo': {
                'retcode': 0,
                'room': {'roomid': '0301', 'room': '0301'},
              },
            }),
          },
          '/Tsm/Elec_Pay_Gateway' => {
            'IsSucceed': true,
            'Obj': jsonEncode({
              'pay_elec_paygw_apply': {
                'retcode': 0,
                'order_no': 'fixture-electricity',
              },
            }),
            'Msg': 'https://openapi.alipay.com/gateway.do?sign=fixture',
          },
          _ => throw StateError('Unexpected endpoint ${o.uri.path}'),
        };
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Wire wire;
  late CampusCardClient client;
  setUp(() {
    wire = _Wire();
    client = CampusCardClient(
      Dio()..httpClientAdapter = wire,
      limiter: RateLimiter(minInterval: Duration.zero),
    );
  });
  tearDown(() => client.close());
  Future<void> connect() => client.fetch(studentNo: '20260000000001');
  test(
    'actual card envelope accepts outer false, keeps units and rejects missing data',
    () {
      final parsed = parseCardInfoResponse({
        'IsSucceed': false,
        'Msg': jsonEncode({
          'query_card': {
            'retcode': '0',
            'card': [cardFixtureRow()],
          },
        }),
      })!;
      expect(parsed.balanceCents, 12850);
      expect(parsed.balanceYuan, 128.50);
      expect(parsed.electricityYuan, 0);
      expect(() => CampusCardInfo.fromCardJson({}), throwsFormatException);
      expect(
        () => CampusCardInfo.fromCardJson({
          ...cardFixtureRow(),
          'db_balance': 'unknown',
        }),
        throwsFormatException,
      );
      expect(() => parseCardInfoResponse('not json'), throwsFormatException);
      expect(
        parseCardInfoResponse({
          'Msg': {
            'query_card': {'retcode': 0, 'card': []},
          },
        }),
        isNull,
      );
    },
  );
  test(
    'one session, verified identity, batch records and explicit refresh',
    () async {
      await Future.wait([connect(), connect()]);
      expect(wire.calls.map((c) => c.uri.path), [
        '/cassyno/index',
        '/Error/PError',
        '/User/GetCardInfo',
      ]);
      expect((wire.calls.first.data as Map)['ssoticketid'], '20260000000001');
      final records = await client.records(CardRecordKind.transactions, 1);
      expect(records.rows, hasLength(15));
      expect(records.nextPage, 2);
      expect(records.rows.first.amount, -12.5);
      expect((wire.calls.last.data as Map)['account'], '900001');
      expect((wire.calls.last.data as Map)['page'], 1);
      await client.fetch(studentNo: '20260000000001', force: true);
      expect(
        wire.calls.where((c) => c.uri.path == '/cassyno/index'),
        hasLength(1),
      );
      expect(
        wire.calls.where((c) => c.uri.path == '/User/GetCardInfo'),
        hasLength(2),
      );
      await expectLater(
        client.fetch(studentNo: '20260000000002'),
        throwsFormatException,
      );
    },
  );
  test('identity mismatch stops before business requests', () async {
    wire.studentNo = '20260000000002';
    await expectLater(connect(), throwsFormatException);
    expect(wire.calls, hasLength(3));
  });
  test('rice final page is retained even when nextpage is zero', () async {
    await connect();
    final page = await client.records(CardRecordKind.rice, 1);
    expect(page.rows, hasLength(1));
    expect(page.nextPage, isNull);
    expect(page.rows.single.time, '2026-11-25 12:00:01');
    expect(page.rows.single.amount, .5);
    final fields = wire.calls.last.data as Map;
    expect(fields['page'], 10);
    expect(fields['index'], 1);
    final categories = await client.billCategories('2026-11');
    expect(categories.single.amount, 0);
  });
  test(
    'recharge sends integer cents and session-owned account exactly once',
    () async {
      await connect();
      final order = await client.recharge(5025);
      expect(order.id, 'fixture-order');
      final fields = wire.calls.last.data as Map;
      expect(fields, containsPair('tranamt', 5025));
      expect(fields, containsPair('account', '900001'));
      expect(fields, containsPair('objtype', 'own'));
      expect(fields, containsPair('paytype', 'alipay'));
      expect(fields, containsPair('iacctype', 'acc'));
      final before = wire.calls.length;
      await expectLater(client.recharge(0), throwsFormatException);
      expect(wire.calls.length, before);
    },
  );
  test(
    'pending write blocks another write and timeout never retries',
    () async {
      await connect();
      wire.holdPayment = Completer<void>();
      final first = client.recharge(1000);
      final assertion = expectLater(
        first,
        throwsA(isA<CampusCardWriteUncertain>()),
      );
      while (!wire.calls.any((c) => c.uri.path == '/User/Account_Pay')) {
        await Future<void>.delayed(Duration.zero);
      }
      await expectLater(
        client.recharge(1000),
        throwsA(isA<CampusCardException>()),
      );
      wire.holdPayment!.completeError(
        DioException(
          requestOptions: wire.calls.last,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      await assertion;
      expect(
        wire.calls.where((c) => c.uri.path == '/User/Account_Pay'),
        hasLength(1),
      );
    },
  );
  test(
    'malformed successful write cannot masquerade as a safe retry',
    () async {
      await connect();
      wire.reply = (o) =>
          o.uri.path == '/User/Account_Pay' ? <String, dynamic>{} : null;
      await expectLater(
        client.recharge(1000),
        throwsA(isA<CampusCardWriteUncertain>()),
      );
    },
  );
  test(
    'electric payment resolves room and completes the scoped order metadata flow',
    () async {
      await connect();
      final room = CardElectricRoom(
        application: const CardChoice('app', '电费'),
        area: const CardChoice('area', '思明校区芙蓉区'),
        building: const CardChoice('building', '测试楼'),
        id: '0301',
        name: '0301',
      );
      final order = await client.payElectricity(room, 2000);
      expect(order.id, 'fixture-electricity');
      expect(wire.calls.skip(3).map((c) => c.uri.path), [
        '/Page/Page',
        '/PPage/ComePage',
        '/Tsm/TsmCommon',
        '/Tsm/Elec_Pay_Gateway',
        '/T_Json/UpdataColsByJson',
      ]);
      final payment = wire.calls[wire.calls.length - 2].data as Map;
      expect(payment['order_amount'], 2000);
      expect(payment['roomid'], '0301');
      expect(payment['account'], '900001');
      final metadata = wire.calls.last.data as Map;
      expect(metadata['keyvalue'], 'fixture-grant');
      expect(metadata['sign'], 'fixture-sign');
      expect(
        metadata['colvalue'],
        'fixture-electricity-1-900001-app-思明校区芙蓉区-测试楼-0301-2000-2026/11/25 12:00:00-###',
      );
    },
  );
  test(
    'Alipay form parsing preserves signed quoted fields and existing query values',
    () {
      final order = cardPaymentOrder({
        'Obj': 'post',
        'OrderID': 'test',
        'Msg':
            '''<form action="https://openapi.alipay.com/gateway.do?charset=utf-8"><input name="sign" value="a&#43;b&amp;c"><input name='biz_content' value='{"amount":"50.25"}'></form>''',
      });
      expect(order.cashier.queryParameters['charset'], 'utf-8');
      expect(order.cashier.queryParameters['sign'], 'a+b&c');
      expect(
        order.cashier.queryParameters['biz_content'],
        '{"amount":"50.25"}',
      );
      expect(
        () => cardPaymentOrder({
          'Msg': 'https://alipay.com.example.org/checkout',
        }),
        throwsA(isA<CampusCardWriteUncertain>()),
      );
    },
  );
  test(
    'card password uses the official PKCS1 RSA envelope and per-request key',
    () async {
      final random = FortunaRandom()
        ..seed(
          KeyParameter(
            Uint8List.fromList(
              List.generate(32, (_) => Random.secure().nextInt(256)),
            ),
          ),
        );
      final generator = RSAKeyGenerator()
        ..init(
          ParametersWithRandom(
            RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 64),
            random,
          ),
        );
      final pair = generator.generateKeyPair();
      final pub = pair.publicKey as RSAPublicKey;
      final private = pair.privateKey as RSAPrivateKey;
      wire.publicKey =
          '${pub.exponent!.toRadixString(16)},${pub.modulus!.toRadixString(16)}';
      await connect();
      await client.lose('123456');
      final payload = wire.calls.last.data as Map;
      expect(wire.calls[wire.calls.length - 2].uri.path, '/Common/GetRsaKey');
      expect(payload['key'], 'fixture-key');
      expect(payload['pwd'], isNot('123456'));
      // Independently inspect the raw RSA block rather than using the production
      // encryption routine or a matching PKCS1 decoder to assert its format.
      final raw = BigInt.parse(payload['pwd'] as String, radix: 16)
          .modPow(private.privateExponent!, private.modulus!)
          .toRadixString(16)
          .padLeft(256, '0');
      final bytes = [
        for (var i = 0; i < raw.length; i += 2)
          int.parse(raw.substring(i, i + 2), radix: 16),
      ];
      expect(bytes.take(2), [0, 2]);
      final separator = bytes.indexOf(0, 2);
      expect(separator, greaterThanOrEqualTo(10));
      expect(utf8.decode(bytes.skip(separator + 1).toList()), '123456');
    },
  );
  test('identity guard stops queued business work before the wire', () async {
    await connect();
    client.identityGuard = () async => false;
    final before = wire.calls.length;
    await expectLater(
      client.records(CardRecordKind.transactions, 1),
      throwsStateError,
    );
    expect(wire.calls.length, before);
  });
}
