import 'dart:async';
import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_repository.dart';

/// Synthetic HTTP boundary; no real identifiers, files or credentials.
class TaHttpFixture implements HttpClientAdapter {
  TaHttpFixture({this.studentCount = 3, this.submittedCount = 2});
  final int studentCount, submittedCount;
  final requests = <RequestOptions>[];
  final scores = <int, double>{};
  Future<ResponseBody?> Function(RequestOptions)? intercept;
  Object? zip = {'id': 71, 'status': 'ready', 'key': 'a' * 40};
  bool group = false;
  bool packed = false;
  static const title = '课程作业：阅读报告与实验分析，这是一份需要单行截断的较长标题';
  Map<String, Object?> get assignment => {
    'id': 81,
    'course_id': 91,
    'title': title,
    'expected_submit_count': studentCount,
    'submitted_count': submittedCount,
    'scored_count': scores.length,
    'type': 'homework',
    'submit_by_group': group,
    'score_type': 'percentage',
    'rubric_id': 0,
    'data': {'mode': 'normal'},
  };
  static ResponseBody response(Object? body, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  Future<TaGradingRepository> repository({RateLimiter? limiter}) async {
    final http = TronHttpClient(
      store: SecureStore.memory(),
      dio: Dio()..httpClientAdapter = this,
      cookieJar: CookieJar(),
      rateLimiter:
          limiter ??
          RateLimiter(minInterval: Duration.zero, maxPerMinute: 10000),
    );
    await http.init();
    return TaGradingRepository(http);
  }

  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    final custom = await intercept?.call(options);
    if (custom != null) return custom;
    final path = options.uri.path;
    if (path.endsWith('/homework-activities')) {
      return response({
        'homework_activities': [assignment],
        'pages': 1,
      });
    }
    if (path == '/api/activities/81') {
      // Captured activity detail contains configuration, not list aggregates.
      return response(
        Map<String, Object?>.from(assignment)
          ..remove('expected_submit_count')
          ..remove('submitted_count')
          ..remove('scored_count'),
      );
    }
    if (path.endsWith('/students')) {
      return response({
        'students': [
          for (var i = 1; i <= studentCount; i++)
            {'id': i, 'user_no': '000$i', 'name': '示例学生$i'},
        ],
      });
    }
    if (path.endsWith('/student-submissions')) {
      return response({
        'submissions': [
          for (var i = 1; i <= submittedCount; i++)
            {
              'id': 100 + i,
              'created_by': {'id': i},
              'score': null,
              'instructor_score': null,
              'marked_submitted': false,
            },
        ],
      });
    }
    if (path.endsWith('/score-records')) {
      final id = int.parse(path.split('/')[5]);
      return response({
        'pages': 1,
        'records': [
          if (scores.containsKey(id))
            {
              'id': 1,
              'created_at': '2026-01-01T00:00:00Z',
              'final_score': scores[id],
            },
        ],
      });
    }
    if (options.method == 'PUT') {
      final data = options.data as Map;
      final id = data['student_id'] as int;
      scores[id] = double.parse(data['score'] as String);
      return response({
        'data': {
          'activity_id': 81,
          'student_id': id,
          'final_score': '${scores[id]}',
        },
        'submission': {'final_score': null},
      }, 201);
    }
    if (path.contains('/zip-status/')) return response({'zip': zip});
    if (path.endsWith('/zip')) {
      packed = true;
      return response({});
    }
    return response({}, 404);
  }
}
