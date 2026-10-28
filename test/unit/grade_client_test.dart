import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/schedule/academic_client.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';

class GradeAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    if (options.method == 'GET' && !options.uri.hasQuery) {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            '/jwapp/sys/cjcx/*default/index.do?EMAP_LANG=zh&test_context=synthetic',
          ],
        },
      );
    }
    return ResponseBody.fromString(
      options.method == 'POST' ? '{}' : '<html></html>',
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}

class DeniedGradeAdapter extends GradeAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '',
      302,
      headers: {
        'location': ['http://jw.xmu.edu.cn/resources/html/403.html'],
      },
    );
  }
}

class Client extends AcademicClient {
  Client() : super(store: SecureStore.memory({SecureStore.keyUserId: '1'}));
  final queries = <Map<String, dynamic>>[];
  final opened = <Uri>[];
  int roleInitializations = 0;
  bool wrongIdentity = false, repeating = false;
  @override
  Future<void> open(Uri uri, {String? username, String? password}) async {
    opened.add(uri);
  }

  @override
  Future<Map<String, dynamic>> json(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    if (path.contains('setJwCommonAppRole')) {
      roleInitializations++;
      return {'success': '1'};
    }
    if (path.contains('initXsxx')) {
      return {
        'success': true,
        'data': {'XH': 'sample'},
      };
    }
    if (path.contains('cxdqxnxq')) {
      return {
        'datas': {
          'cxdqxnxqhsygxnxq': {
            'rows': [
              {'XNXQDM': '2026-2027-1'},
              {'XNXQDM': '2025-2026-9'},
            ],
          },
        },
      };
    }
    queries.add(data!);
    final q = jsonDecode(data['querySetting'] as String) as List;
    final term =
        q.where((r) => r['name'] == 'XNXQDM').firstOrNull?['value'] ?? 'all';
    return {
      'datas': {
        'xscjcx': {
          'totalSize': repeating ? 5 : 1,
          'rows': [
            {
              'WID': 'record-$term',
              'XH': wrongIdentity ? 'other' : 'sample',
              'KCM': 'Test',
              'XF': '2',
              'JDF': '3.7',
              'DJCJLXDM': '100',
              'KCLBDM_DISPLAY': '通识教育课程',
              'XNXQDM': term,
            },
          ],
        },
      },
    };
  }
}

class GraduateClient extends Client {
  List<Map<String, dynamic>> rows = [];
  bool malformed = false;
  int responseCode = 0;
  @override
  Future<void> open(Uri uri, {String? username, String? password}) async {
    opened.add(uri);
    if (uri.queryParameters['appId'] == '4768574631264620') {
      throw const AcademicApplicationDenied();
    }
  }

  @override
  Future<Map<String, dynamic>> json(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    if (!path.contains('xscjcx_by')) return super.json(path, data: data);
    queries.add(data!);
    return {
      'code': '$responseCode',
      'datas': malformed
          ? {}
          : {
              'xscjcx_by': {'rows': rows, 'totalSize': rows.length},
            },
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'application denial is classified before following its HTTP error page',
    () async {
      final adapter = DeniedGradeAdapter();
      final client = AcademicClient(
        store: SecureStore.memory(),
        dio: Dio()..httpClientAdapter = adapter,
        limiter: RateLimiter(minInterval: Duration.zero),
      );
      await expectLater(
        client.open(AcademicClient.jw.resolve('/appShow')),
        throwsA(isA<AcademicApplicationDenied>()),
      );
      expect(adapter.requests.length, 1);
      expect(adapter.requests.single.uri.scheme, 'https');
      client.dio.close();
    },
  );
  test(
    'graduate application returns a valid empty result for unpublished grades',
    () async {
      final client = GraduateClient();
      final result = await client.fetchGrades(
        1,
        username: 'sample',
        recent: true,
      );
      expect(client.opened.last.queryParameters['appId'], '5094115980385668');
      expect(result.education, 'graduate');
      expect(result.complete, isTrue);
      expect(result.rows, isEmpty);
      expect(client.queries.single, {'pageSize': 100, 'pageNumber': 1});
      await expectLater(
        (GraduateClient()..malformed = true).fetchGrades(1, username: 'sample'),
        throwsFormatException,
      );
      await expectLater(
        (GraduateClient()..responseCode = 1).fetchGrades(1, username: 'sample'),
        throwsFormatException,
      );
    },
  );
  test(
    'graduate JDZ and course fields map independently without losing repeated attempts',
    () async {
      final client = GraduateClient()
        ..rows = [
          for (var n = 0; n < 2; n++)
            {
              'XH': 'sample',
              'KCDM': 'GS101',
              'KCMC': '研究生测试课',
              'XNXQDM': '20261',
              'XF': 3,
              'CJXSZ': '88',
              'CJ': 88,
              'JDZ': 3.5,
              'SFYX': '1',
            },
        ];
      final result = await client.fetchGrades(1, username: 'sample');
      expect(result.rows.length, 2);
      expect(result.rows.map((r) => r['WID']).toSet().length, 2);
      expect(result.rows.first['JDF'], 3.5);
      expect(result.rows.first['XNXQDM'], '2026-2027-1');
      expect(result.rows.first.containsKey('XH'), isFalse);
      expect(result.rows.first['GRADE_SYSTEM'], 'graduate');
      await expectLater(
        (GraduateClient()
              ..rows = [
                {'XH': 'another'},
              ])
            .fetchGrades(1, username: 'sample'),
        throwsFormatException,
      );
    },
  );
  test(
    'grade AJAX retains its application context and same-origin headers',
    () async {
      final adapter = GradeAdapter();
      final client = AcademicClient(
        store: SecureStore.memory(),
        dio: Dio()..httpClientAdapter = adapter,
        limiter: RateLimiter(minInterval: Duration.zero),
      );
      await client.open(
        AcademicClient.jw.resolve('/jwapp/sys/cjcx/*default/index.do'),
      );
      await client.json('/jwapp/sys/cjcx/modules/cjcx/xscjcx.do', data: {});
      final request = adapter.requests.last;
      expect(request.headers['X-Requested-With'], 'XMLHttpRequest');
      expect(request.headers['Origin'], 'https://jw.xmu.edu.cn');
      expect(request.headers['Referer'], contains('test_context=synthetic'));
      expect(
        adapter.requests.first.headers.containsKey('X-Requested-With'),
        isFalse,
      );
      client.dio.close();
    },
  );
  test(
    'full and recent use captured endpoints and minimize persisted columns',
    () async {
      final all = Client();
      final result = await all.fetchGrades(1, username: 'sample');
      expect(all.queries.length, 1);
      expect(all.roleInitializations, 1);
      expect(all.opened.last.path, '/appShow');
      expect(all.opened.last.queryParameters['appId'], '4768574631264620');
      expect(result.replacedTerms, isEmpty);
      expect(result.rows.single.containsKey('XH'), isFalse);
      expect(result.rows.single['DJCJLXDM'], '100');
      expect(result.rows.single['KCLBDM_DISPLAY'], '通识教育课程');
      final recent = Client();
      final delta = await recent.fetchGrades(
        1,
        username: 'sample',
        recent: true,
      );
      expect(recent.queries.length, 2);
      expect(delta.replacedTerms, {'2026-2027-1', '2025-2026-9'});
    },
  );
  test(
    'wrong account and ignored pagination never become a complete cache',
    () async {
      await expectLater(
        (Client()..wrongIdentity = true).fetchGrades(1, username: 'sample'),
        throwsFormatException,
      );
      await expectLater(
        (Client()..repeating = true).fetchGrades(1, username: 'sample'),
        throwsFormatException,
      );
    },
  );
}
