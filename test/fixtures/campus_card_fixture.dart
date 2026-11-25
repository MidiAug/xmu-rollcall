import 'dart:async';
import 'package:dio/dio.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_client.dart';
import 'package:xmu_rollcall/features/campus_card/electricity_client.dart';

CampusCardInfo cardFixture({String account = '900001', bool lost = false}) =>
    CampusCardInfo(
      account: account,
      cardName: '校园卡',
      balanceCents: 12850,
      unsettledCents: 0,
      electricityCents: 0,
      expiryDate: '20301231',
      createdDate: '20230901',
      studentNo: '20260000000001',
      lost: lost,
      frozen: false,
    );
Map<String, dynamic> cardFixtureRow({String studentNo = '20260000000001'}) => {
  ...cardFixture().toJson(),
  'sno': studentNo,
};
CardRecord recordFixture(int i) => CardRecord(
  title: '测试食堂$i',
  kind: '消费',
  time: '2026-11-25 12:00:00',
  amount: -12.50,
  balance: 128.50,
  note: '',
  number: 'test-$i',
);

class CampusCardFixtureClient extends CampusCardClient {
  CampusCardFixtureClient() : super(Dio());
  CampusCardInfo value = cardFixture();
  bool fail = false, uncertain = false, failLaunch = false;
  int fetchCount = 0;
  int electricDirectoryReads = 0;
  Completer<CampusCardInfo>? pending;
  Completer<void>? pendingWrite;
  final writes = <String>[];
  final pages = <int>[];
  int? cents;
  @override
  Future<CampusCardInfo> fetch({
    required String studentNo,
    CancelToken? cancelToken,
    bool force = false,
  }) async {
    fetchCount++;
    if (pending != null) return pending!.future;
    if (fail) throw const CampusCardException('网络暂不可用');
    return value;
  }

  @override
  Future<CardRecordPage> records(CardRecordKind kind, int page) async {
    pages.add(page);
    if (fail) throw const CampusCardException('读取失败');
    return CardRecordPage([
      for (var i = 0; i < (page == 1 ? 15 : 2); i++)
        recordFixture((page - 1) * 15 + i),
    ], page == 1 ? 2 : null);
  }

  @override
  Future<List<CardBillCategory>> billCategories(String month) async => [
    CardBillCategory({'code': 'food', 'name': '餐饮', 'value': '128.50'}),
  ];
  @override
  Future<List<CardRecord>> categoryRecords(String month, String code) async => [
    recordFixture(0),
  ];
  @override
  Future<List<({String name, double balance})>> accounts() async => [];
  @override
  Future<List<CardChoice>> electricApplications() async {
    electricDirectoryReads++;
    return [const CardChoice('elec', '宿舍电费')];
  }

  @override
  Future<List<CardChoice>> electricAreas(CardChoice app) async => [
    const CardChoice('area', '思明校区芙蓉区'),
  ];
  @override
  Future<List<CardChoice>> electricBuildings(
    CardChoice app,
    CardChoice area,
  ) async => [const CardChoice('building', '测试楼')];
  @override
  Future<CardElectricRoom> electricRoom(
    CardChoice app,
    CardChoice area,
    CardChoice building,
    String room,
  ) async => CardElectricRoom(
    application: app,
    area: area,
    building: building,
    id: room,
    name: room,
  );
  @override
  Future<CardPaymentOrder> recharge(int amount) async {
    writes.add('recharge');
    cents = amount;
    await pendingWrite?.future;
    if (uncertain) throw const CampusCardWriteUncertain();
    return CardPaymentOrder(
      Uri.parse('https://openapi.alipay.com/gateway.do?sign=fixture'),
      'test-order',
    );
  }

  @override
  Future<CardPaymentOrder> payElectricity(
    CardElectricRoom room,
    int amount,
  ) async {
    writes.add('electricity');
    cents = amount;
    return CardPaymentOrder(
      Uri.parse('https://openapi.alipay.com/gateway.do?sign=fixture'),
      'test-electricity',
    );
  }

  @override
  Future<void> lose(String password) async {
    writes.add('lost');
    value = cardFixture(lost: true);
  }

  @override
  Future<void> sendPasswordCode() async {
    writes.add('sms');
  }

  @override
  Future<void> changePassword(String password, String code) async {
    writes.add('password');
  }
}

CardElectricRoom electricRoomFixture(String room) => CardElectricRoom(
  application: const CardChoice('elec', '宿舍电费'),
  area: const CardChoice('area', '思明校区芙蓉区'),
  building: const CardChoice('building', '测试楼'),
  id: room,
  name: room,
);

class ElectricityFixtureClient extends ElectricityClient {
  final calls = <String>[];
  @override
  Future<ElectricReading> read(CardElectricRoom room) async {
    calls.add(room.id);
    return ElectricReading(
      room: room,
      balance: room.id.endsWith('00') ? 58.25 : 42.50,
      kwh: 100,
      checkedAt: DateTime.now(),
      reportedAt: '2026-11-24',
    );
  }
}
