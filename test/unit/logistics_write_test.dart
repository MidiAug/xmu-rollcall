import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/features/logistics/logistics_client.dart';
import 'package:xmu_rollcall/features/logistics/logistics_form_models.dart';

class _Wire implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  bool allow = true, timeout = false;
  Completer<void>? hold;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(o);
    if (o.uri.host == 'ids.xmu.edu.cn') {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            'https://xdhq.xmu.edu.cn/appAccount/login?userinfo=test',
          ],
        },
      );
    }
    final path = o.uri.path;
    if (path.endsWith('/publish/publish') ||
        path.endsWith('/supervisionPost/save')) {
      await hold?.future;
      if (timeout) {
        throw DioException(
          requestOptions: o,
          type: DioExceptionType.receiveTimeout,
        );
      }
    }
    final data = switch (path) {
      '/api/auth/login/auto' => 'test-token',
      '/api/auth/user/info' => {
        'account': 'fixture',
        'id': 'test-user',
        'name': '测试用户',
      },
      '/api/repair/publish/getAcceptUserByAreaIdAndProjectId' => {
        'dept': {'deptId': 'dept', 'deptName': '服务单位', 'payName': '无偿'},
        'users': [],
      },
      '/api/repair/oneNetPublish/checkIfHadProjectIdByAreaId' => true,
      '/api/repair/publish/publish' ||
      '/api/supervise/supervisionPost/save' => {'id': 'new-record'},
      '/api/repair/myRepair/ifAllowWithdrawMyRepair' => allow ? 1 : 0,
      '/api/repair/myRepair/withdrawMyRepair' => true,
      '/api/repair/repairInfo/get' => {
        'id': 'repair',
        'status': '4',
        'ifCommont': '0',
      },
      '/api/repair/visitEvaluateUser/save' ||
      '/api/supervise/supervisionPost/deleteByIdByStudent' ||
      '/api/manager/systemPersonalWait/statusMessage' => true,
      '/api/file/upload' => {'path': '/manager/test.jpg'},
      _ => throw StateError('Unexpected endpoint $path'),
    };
    final body = jsonEncode({
      'status': 'success',
      'errorCode': 0,
      'data': data,
    });
    return ResponseBody.fromString(
      path.endsWith('/file/upload') ? body : logisticsEncrypt(body),
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(LogisticsClient, _Wire)> _session() async {
  final wire = _Wire();
  final client = LogisticsClient(
    dio: Dio()..httpClientAdapter = wire,
    limiter: RateLimiter(maxPerMinute: 1000, minInterval: Duration.zero),
  );
  await client.connect(username: 'fixture');
  return (client, wire);
}

void main() {
  test(
    'repair write follows recipient and project validation once, using JSON',
    () async {
      final (c, w) = await _session();
      await c.submitRepair({
        'areaId': 'building',
        'projectId': 'pipe',
        'content': '测试故障',
      });
      final business = w.calls.skip(3).map((r) => r.uri.path).toList();
      expect(business, [
        '/api/repair/publish/getAcceptUserByAreaIdAndProjectId',
        '/api/repair/oneNetPublish/checkIfHadProjectIdByAreaId',
        '/api/repair/publish/publish',
      ]);
      expect(w.calls.last.contentType, startsWith(Headers.jsonContentType));
      final body = w.calls.last.data as Map;
      expect(body['acceptDeptId'], 'dept');
      expect(body['acceptDeptName'], '服务单位');
    },
  );
  test(
    'feedback identity is session owned, phone is encoded and deletion carries reason',
    () async {
      final (c, w) = await _session();
      await c.submitFeedback({
        'phone': '13800000000',
        'postUserId': 'incorrect',
        'postUserName': 'incorrect',
        'serverType': 1,
      });
      final sent = w.calls.last.data as Map;
      expect(sent['postUserId'], 'test-user');
      expect(sent['postUserName'], '测试用户');
      expect(sent['phone'], isNot('13800000000'));
      expect(sent['serverType'], 1);
      await c.deleteFeedback('new-record', '测试结束');
      expect(w.calls.last.data, {'postId': 'new-record', 'remark': '测试结束'});
    },
  );
  test(
    'withdraw respects server eligibility and rereads authoritative detail',
    () async {
      final (c, w) = await _session();
      w.allow = false;
      await expectLater(c.withdraw('repair'), throwsFormatException);
      expect(
        w.calls.where((r) => r.uri.path.endsWith('/withdrawMyRepair')),
        isEmpty,
      );
      w.allow = true;
      await c.withdraw('repair');
      expect(w.calls.last.uri.path, '/api/repair/repairInfo/get');
    },
  );
  test(
    'one pending write rejects a second; timeout is not automatically retried',
    () async {
      final (c, w) = await _session();
      w.hold = Completer<void>();
      w.timeout = true;
      final first = c.submitFeedback({'phone': '13800000000'});
      final uncertain = expectLater(
        first,
        throwsA(isA<LogisticsWriteUncertain>()),
      );
      while (!w.calls.any(
        (r) => r.uri.path.endsWith('/supervisionPost/save'),
      )) {
        await Future<void>.delayed(Duration.zero);
      }
      await expectLater(
        c.submitFeedback({'phone': '13800000000'}),
        throwsFormatException,
      );
      w.hold!.complete();
      await uncertain;
      expect(
        w.calls
            .where((r) => r.uri.path.endsWith('/supervisionPost/save'))
            .length,
        1,
      );
    },
  );
  test(
    'evaluation rechecks the current repair and upload uses native multipart',
    () async {
      final (c, w) = await _session();
      await c.evaluate(
        'repair',
        [
          {'id': 'score', 'name': '服务态度', 'weight': 100, 'star': 5},
        ],
        '谢谢',
        ['态度很好'],
      );
      expect(w.calls.last.data, containsPair('source', '0'));
      expect((w.calls.last.data as Map)['label'], '态度很好');
      expect(
        w.calls[w.calls.length - 2].uri.path,
        '/api/repair/repairInfo/get',
      );
      expect(
        await c.upload(
          openRead: () => Stream.value([1, 2, 3]),
          length: 3,
          name: 'test.jpg',
        ),
        '/manager/test.jpg',
      );
      expect(w.calls.last.data, isA<FormData>());
      expect(
        Map.fromEntries((w.calls.last.data as FormData).fields),
        containsPair('system', 'manager'),
      );
    },
  );
  test('option trees preserve path IDs and server leaf names', () {
    final choice = logisticsChoices([
      {
        'id': 'department',
        'name': '服务部',
        'children': [
          {'id': 'scope', 'name': '公寓服务', 'uploadStatus': '1'},
        ],
      },
    ]).single;
    expect(choice.ids, ['department', 'scope']);
    expect(choice.leafName, '公寓服务');
    expect(choice.label, '服务部/公寓服务');
    expect(choice.imageRequired, isTrue);
  });
  test(
    'display paths split campus grouping without changing submission fields',
    () {
      final choice = logisticsChoices([
        {
          'id': 'district',
          'name': '思明校区-教工住宅东区',
          'children': [
            {'id': 'building01', 'name': '海滨东区01'},
          ],
        },
      ]).single;
      expect(choice.path, ['思明校区', '教工住宅东区', '海滨东区01']);
      // Old constructor-shaped options need no extra initialized display state.
      const existing = LogisticsChoice('building01', '思明校区-教工住宅东区/海滨东区01');
      expect(existing.path, choice.path);
      expect(choice.label, '思明校区-教工住宅东区/海滨东区01');
      expect(choice.ids, ['district', 'building01']);
      expect(choice.id, 'building01');
      expect(logisticsPhone('13800000000', repair: true), isNull);
      expect(logisticsPhone('not-a-phone', repair: true), isNotNull);
    },
  );
}
