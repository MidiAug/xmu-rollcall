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
  final writes = <String>[];
  Map<String, dynamic>? lastForm;
  bool deleted = false;
  Completer<void>? submission;
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
            'id': 'fixture-message',
            'content': '您的单据已完工，请及时评价！',
            'sendTime': '2026-11-12 17:59',
            'status': 0,
          },
      ],
    };
  }

  @override
  Future<Object?> areas() async => [
    {
      'id': 'campus',
      'name': '翔安校区',
      'children': [
        {'id': 'building', 'name': '测试楼'},
      ],
    },
  ];
  @override
  Future<Object?> projects(String area) async => [
    {
      'value': 'water',
      'label': '水',
      'children': [
        {'value': 'pipe', 'label': '管道维修'},
      ],
    },
  ];
  @override
  Future<Object?> repairSettings() async => [
    {'code': '011', 'value': '[]'},
    {'code': '521', 'value': '1'},
  ];
  @override
  Future<Map<String, dynamic>> repairRecipient(
    String area,
    String project,
  ) async => {
    'dept': {'deptId': 'unit', 'deptName': '测试维修部', 'payName': '无偿'},
    'users': [],
  };
  @override
  Future<Map<String, dynamic>> repairDetail(String id) async => {
    ...logisticsRepairFixture(0),
    'id': id,
    'status': '4',
    'logVOS': logisticsRepairFixture(0)['logs'],
    'finishedInfo': {
      'paymentTypeName': '无偿',
      'workerList': [],
      'beforeImg': '',
      'afterImg': '',
    },
  };
  @override
  Future<bool> canWithdraw(String id) async => false;
  @override
  Future<String> submitRepair(Map<String, dynamic> form) async {
    writes.add('repair');
    lastForm = form;
    await submission?.future;
    return 'created-repair';
  }

  @override
  Future<Object?> feedbackScopes() async => [
    {
      'id': 'unit',
      'name': '测试服务部',
      'children': [
        {'id': 'service', 'name': '公寓服务'},
      ],
    },
  ];
  @override
  Future<Object?> feedbackTypes() async => [
    {'id': '2', 'name': '咨询'},
    {'id': '1', 'name': '建议'},
    {'id': '3', 'name': '表扬'},
    {'id': '0', 'name': '投诉'},
  ];
  @override
  Future<String> submitFeedback(Map<String, dynamic> form) async {
    writes.add('feedback');
    lastForm = form;
    await submission?.future;
    return 'created-feedback';
  }

  Map<String, dynamic> get feedbackRow => {
    'id': 'post',
    'postTitle': '测试服务反馈',
    'content': '请改善公寓服务',
    'serviceScopeName': '公寓服务',
    'typeName': '建议',
    'createTime': '2026-11-25 11:00',
    'ifDelete': deleted ? 1 : 0,
    'replyCount': 1,
    'images': '',
  };
  @override
  Future<Map<String, dynamic>> feedbackPosts(int page) async => {
    'total': 1,
    'rows': [feedbackRow],
  };
  @override
  Future<Map<String, dynamic>> feedbackDetail(String id) async => {
    ...feedbackRow,
    'allowDeleteTime': '2099-01-01 00:00:00',
  };
  @override
  Future<Object?> feedbackReplies(String id) async => {
    'total': 1,
    'rows': [
      {
        'id': 'reply',
        'ifOfficial': 1,
        'status': '1',
        'replyUserName': '服务部门',
        'content': '我们已经收到建议',
        'createTime': '2026-11-25 11:01',
      },
    ],
  };
  @override
  Future<void> deleteFeedback(String id, String reason) async {
    writes.add('delete');
    deleted = true;
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    int page, {
    String status = '',
  }) async => messages();
  @override
  Future<void> markMessageRead(String id) async {
    writes.add('read');
  }

  @override
  Future<Object?> evaluationFields() async => [
    for (final item in ['服务态度', '服务质量', '维修质量', '维修速度'])
      {'id': item, 'name': item, 'weight': 25, 'star': null},
  ];
  @override
  Future<Object?> evaluationLabels() async => [
    {'id': 'label', 'name': '维修速度很快'},
  ];
  @override
  Future<void> evaluate(
    String id,
    List<Map<String, dynamic>> scores,
    String content,
    List<String> labels,
  ) async {
    writes.add('evaluate');
  }
}
