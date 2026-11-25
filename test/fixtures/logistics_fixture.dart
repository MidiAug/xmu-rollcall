import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:xmu_rollcall/features/logistics/logistics_client.dart';

Map<String, dynamic> logisticsRepairFixture(int index) => {
  'id': 'fixture-$index',
  'serialNumber': 'TEST$index',
  'projectName': '水/厕所设施设备',
  'content': '洗手池下水堵塞，请检查管道',
  'areaName': '翔安校区-学生公寓',
  'address': '测试楼101',
  'repairDeptName': '测试维修部',
  'workerName': '测试维修人员',
  'ifComplete': '1',
  'ifCommont': '0',
  'logs': [
    {'statusName': '完工', 'createTime': '2026-11-12 17:59', 'content': '维修已完成'},
    {
      'statusName': '派工',
      'createTime': '2026-11-12 17:01',
      'content': '已指派维修人员',
    },
    {'statusName': '审核', 'createTime': '2026-11-12 16:59', 'content': '审核通过'},
    {'statusName': '报修', 'createTime': '2026-11-12 16:59', 'content': '等待受理'},
  ],
};

/// Only the network boundary is replaced; models, cache, pagination and UI
/// continue through the production provider.
class LogisticsFixtureClient extends LogisticsClient {
  LogisticsFixtureClient({this.total = 1});
  final int total;
  bool fail = false;
  Completer<void>? pending;
  final pages = <int>[];
  int messageRequests = 0;
  @override
  Future<void> connect({
    required String username,
    String? password,
    CookieJar? sso,
  }) async {}
  @override
  Future<Map<String, dynamic>> repairs(int page) async {
    pages.add(page);
    await pending?.future;
    if (fail) throw const FormatException('网络暂不可用');
    final start = (page - 1) * 20;
    return {
      'total': total,
      'rows': [
        for (var i = start; i < total && i < start + 20; i++)
          logisticsRepairFixture(i),
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> messages() async {
    messageRequests++;
    return {
      'total': total == 0 ? 0 : 1,
      'rows': [
        if (total != 0)
          {
            'title': '报修服务进度提醒',
            'content': '您的单据已完工，请及时评价！',
            'sendTime': '2026-11-12 17:59',
            'status': 0,
          },
      ],
    };
  }
}
