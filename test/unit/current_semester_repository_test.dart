import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

class _Adapter implements HttpClientAdapter {
  final conditions = <Map>[];
  bool empty = false;
  bool failPost = false;
  int fallbackGets = 0;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    Object body;
    var status = 200;
    if (request.path.endsWith('/current-semester-info')) {
      body = {
        'semester': {'id': 29},
        'academic_year': {'id': 12},
      };
    } else if (request.method == 'POST') {
      final filter = (request.data as Map)['conditions'] as Map;
      conditions.add(filter);
      if (failPost) {
        status = 404;
        body = {'error': 'unavailable'};
      } else {
        body = {
          'courses': empty || !(filter['role'] as List).contains('student')
              ? []
              : _courses,
        };
      }
    } else {
      fallbackGets++;
      body = {'courses': _courses};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  List<Map<String, Object>> get _courses => [
    {'id': 1, 'name': '本学期', 'semester_id': 29, 'academic_year_id': 12},
    {
      'id': 2,
      'name': '上学期',
      'semester': {'id': 28},
      'academic_year_id': 12,
    },
    {
      'id': 3,
      'name': '往年同学期',
      'semester_id': 29,
      'academic_year': {'id': 11},
    },
    {'id': 4, 'name': '无学期字段'},
  ];
}

void main() {
  late _Adapter adapter;
  late RollcallRepository repo;
  setUp(() {
    adapter = _Adapter();
    final store = SecureStore.memory();
    final dio = Dio()..httpClientAdapter = adapter;
    dio.options.headers['Cookie'] = 'session=test';
    repo = RollcallRepository(
      http: TronHttpClient(
        store: store,
        dio: dio,
        cookieJar: CookieJar(),
        rateLimiter: RateLimiter(minInterval: Duration.zero),
      ),
      identity: DeviceIdentity(store),
    );
  });

  test(
    'all course and membership queries use the current semester and year',
    () async {
      final snap = await repo.fetchCourseCatalog();
      expect(snap.semesterId, '29');
      expect(snap.academicYearId, '12');
      expect(snap.termResolved, isTrue);
      expect(snap.courses.map((c) => c.id), ['1', '4']);
      expect(adapter.conditions, hasLength(3));
      for (final filter in adapter.conditions) {
        expect(filter['semester_id'], ['29']);
        expect(filter['academic_year_id'], ['12']);
        expect(
          filter.containsKey('status'),
          isFalse,
          reason:
              'Current-term courses must include courses that have already finished',
        );
      }
    },
  );

  test(
    'a valid empty current-semester list never falls back to all past courses',
    () async {
      adapter.empty = true;
      final snap = await repo.fetchCourseCatalog();
      expect(snap.courses, isEmpty);
      expect(snap.termResolved, isTrue);
      expect(adapter.fallbackGets, 0);
    },
  );

  test('legacy GET fallback excludes past and unscoped courses', () async {
    adapter.failPost = true;
    final snap = await repo.fetchCourseCatalog();
    expect(snap.courses.map((c) => c.id), ['1']);
    expect(snap.termResolved, isTrue);
  });
}
