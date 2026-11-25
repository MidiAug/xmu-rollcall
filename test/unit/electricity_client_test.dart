import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/features/campus_card/electricity_client.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_models.dart';

const initial =
    '<input type="hidden" name="__VIEWSTATE" value="state-0"><input type="submit" name="dxbtnQuery" value="查询"><select name="drxiaoqu"><option value="55">翔安校区博士后公寓区</option></select>';
const area =
    '<input type="hidden" name="__VIEWSTATE" value="state-1"><select name="drlou"><option value="DX1">DX1</option><option value="DX2">DX2</option></select>';
const result =
    '<label id="lableft">账户余额：-2.50元    剩余电量：-5.00度</label><tr id="dxgvElec_DXDataRow0"><td>2026-11-24</td></tr>';
CardElectricRoom room(String id) => CardElectricRoom(
  application: const CardChoice('elec', '宿舍电费'),
  area: const CardChoice('55', '翔安校区博士后公寓区'),
  building: const CardChoice('new-building', '笃行1号'),
  id: id,
  name: id,
);

class _Wire implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls.add(o);
    final data = o.data as Map?;
    return ResponseBody.fromString(
      o.method == 'GET'
          ? initial
          : data?['txtRoomid'] == ''
          ? area
          : result,
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'parses real labels, negative balances, energy and source date without invented zero',
    () {
      final value = parseElectricReading(result, room('0301'));
      expect(value.balance, -2.5);
      expect(value.kwh, -5);
      expect(value.reportedAt, '2026-11-24');
      expect(
        () => parseElectricReading('<html>no data</html>', room('0301')),
        throwsFormatException,
      );
    },
  );
  test(
    'personal and common rooms share one directory lookup and never need credentials',
    () async {
      final wire = _Wire();
      final client = ElectricityClient(
        dio: Dio()..httpClientAdapter = wire,
        limiter: RateLimiter(minInterval: Duration.zero),
      );
      addTearDown(client.close);
      await client.read(room('0301'));
      await client.read(room('0300'));
      expect(wire.calls, hasLength(4));
      expect(wire.calls.map((v) => v.method), ['GET', 'POST', 'POST', 'POST']);
      for (final call in wire.calls) {
        expect(call.uri.host, 'elec.xmu.edu.cn');
        expect(call.headers.containsKey('Authorization'), isFalse);
      }
      final post = wire.calls[2].data as Map;
      expect(post['__VIEWSTATE'], 'state-1');
      expect(post['drlou'], 'DX1');
      expect(post['txtRoomid'], '0301');
    },
  );
  test(
    'identity guard stops anonymous queries from publishing into another account',
    () async {
      final wire = _Wire();
      final client = ElectricityClient(
        dio: Dio()..httpClientAdapter = wire,
        limiter: RateLimiter(minInterval: Duration.zero),
      );
      addTearDown(client.close);
      client.identityGuard = () async => false;
      await expectLater(client.read(room('0301')), throwsStateError);
      expect(wire.calls, isEmpty);
    },
  );
}
