import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_repository.dart';

class _Adapter implements HttpClientAdapter {
  bool failRoles = false;
  Object? catalogPayload;
  Object? rolePayload;
  int postStatus = 200;
  final requests = <RequestOptions>[];
  bool emptyInstructors = false;
  final roles = <List<String>>[];
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    if (options.method == 'GET') {
      return ResponseBody.fromString(
        '{"courses":[]}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (postStatus != 200) return ResponseBody.fromString('{}', postStatus);
    final body = options.data as Map;
    final filters = List<String>.from(
      (body['conditions'] as Map)['role'] as List,
    );
    roles.add(filters);
    final full = filters.contains('student');
    final data = {
      'courses': full
          ? [
              for (final id in [1, 2, 3])
                {
                  'id': id,
                  'name': 'Course $id',
                  'timetables': {
                    '1': [
                      {
                        'sequence': 1,
                        'start_time': '08:00',
                        'end_time': '09:00',
                      },
                    ],
                  },
                },
            ]
          : filters.contains('instructor')
          ? [
              {'id': 3},
            ]
          : [
              {'id': 2},
            ],
    };
    return ResponseBody.fromString(
      jsonEncode(
        full && catalogPayload != null
            ? catalogPayload
            : !full && rolePayload != null
            ? rolePayload
            : !full && failRoles
            ? {'error': 'unavailable'}
            : !full && filters.contains('instructor') && emptyInstructors
            ? {}
            : data,
      ),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
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
    'backend memberships distinguish students, assistants and instructors',
    () async {
      final catalog = await repo.fetchCourseCatalog();
      expect(catalog.rolesResolved, isTrue);
      expect(catalog.courses.map((c) => c.roleLabel), ['学生', '助教', '教师']);
      expect(catalog.attendanceTitlesById.keys, ['1']);
      expect(catalog.teachingCourses.map((c) => c.id), ['2', '3']);
      final restored = CourseCatalogSnapshot.fromJson(catalog.toJson());
      expect(restored.courses[1].isTeachingAssistant, isTrue);
      expect(restored.rolesResolved, isTrue);
      expect(adapter.roles[1], ['student_assistant', 'instructor_assistant']);
    },
  );
  test(
    'unavailable role responses do not guess that student courses are teaching courses',
    () async {
      adapter.failRoles = true;
      final catalog = await repo.fetchCourseCatalog();
      expect(catalog.rolesResolved, isFalse);
      expect(catalog.courses.every((c) => !c.isTeaching), isTrue);
    },
  );

  test(
    'platform empty object represents no courses for a queried role',
    () async {
      adapter.emptyInstructors = true;
      final catalog = await repo.fetchCourseCatalog();
      expect(catalog.rolesResolved, isTrue);
      expect(catalog.courses[1].isTeachingAssistant, isTrue);
      expect(catalog.courses.where((c) => c.isInstructor), isEmpty);
    },
  );
  for (final payload in <Object>[
    [],
    {},
    {'courses': []},
    {
      'data': {'courses': []},
    },
  ]) {
    test('valid empty catalog $payload needs only one request', () async {
      adapter.catalogPayload = payload;
      final result = await repo.fetchCourseCatalog();
      expect(result.courses, isEmpty);
      expect(result.rolesResolved, isTrue);
      expect(adapter.requests, hasLength(1));
    });
  }
  for (final payload in <Object>[
    {
      'courses': [
        {'id': 1},
        42,
      ],
    },
    {
      'courses': [
        {'id': 1},
        {'name': 'missing id'},
      ],
    },
    {
      'courses': [
        {'id': {}},
      ],
    },
    {'error': 'unavailable'},
    {'courses': null},
  ]) {
    test('bad catalog $payload is rejected without probing', () async {
      adapter.catalogPayload = payload;
      await expectLater(repo.fetchCourseCatalog(), throwsFormatException);
      expect(adapter.requests, hasLength(1));
    });
  }
  test('bad role row never marks incomplete memberships as resolved', () async {
    adapter.rolePayload = {
      'courses': [
        {'id': 2},
        42,
      ],
    };
    expect((await repo.fetchCourseCatalog()).rolesResolved, isFalse);
  });
  test('unsupported POST accepts the first valid empty GET response', () async {
    adapter.postStatus = 405;
    expect((await repo.fetchCourseCatalog()).courses, isEmpty);
    expect(adapter.requests.map((r) => r.method), ['POST', 'GET']);
  });
  test(
    'authentication failure does not trigger compatibility probes',
    () async {
      adapter.postStatus = 401;
      await expectLater(
        repo.fetchCourseCatalog(),
        throwsA(isA<DioException>()),
      );
      expect(adapter.requests, hasLength(1));
    },
  );
}
