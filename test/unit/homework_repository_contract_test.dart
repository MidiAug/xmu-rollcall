import 'dart:async';
import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/homework/homework_repository.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';

class _Adapter implements HttpClientAdapter {
  Object payload = {};
  Future<void>? gate;
  void Function()? onRequest;
  final requests = <RequestOptions>[];
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    onRequest?.call();
    await gate;
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late _Adapter adapter;
  late HomeworkRepository repo;
  setUp(() {
    adapter = _Adapter();
    repo = HomeworkRepository(
      http: TronHttpClient(
        store: SecureStore.memory(),
        dio: Dio()..httpClientAdapter = adapter,
        cookieJar: CookieJar(),
        rateLimiter: RateLimiter(minInterval: Duration.zero),
      ),
    );
  });
  test(
    'personal status uses the read-only student route and accepts a published zero score',
    () async {
      adapter.payload = {
        'list': [
          {
            'id': 9,
            'is_draft': false,
            'submitted_at': '2026-10-22T00:00:00Z',
            'is_announce_score_time_passed': true,
            'score': 0,
          },
        ],
      };
      final status = await repo.fetchSubmission(activityId: 8, studentId: 1);
      expect(status.grading, HomeworkGrading.graded);
      expect(status.score, 0);
      expect(
        adapter.requests.single.uri.path,
        '/api/activities/8/students/1/submission_list',
      );
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.data, isNull);
    },
  );
  test(
    'malformed success bodies fail instead of overwriting old lists with empty data',
    () async {
      adapter.payload = {'error': 'unavailable'};
      await expectLater(repo.fetchTodos(), throwsFormatException);
      await expectLater(repo.fetchCourseHomework(1), throwsFormatException);
      await expectLater(
        repo.fetchSubmission(activityId: 8, studentId: 1),
        throwsFormatException,
      );
      adapter.payload = {'todo_list': []};
      expect(await repo.fetchTodos(), isEmpty);
      adapter.payload = {'homework_activities': [], 'pages': 1};
      expect(await repo.fetchCourseHomework(1), isEmpty);
    },
  );
  test(
    'an exact full page does not cause a redundant second page request',
    () async {
      adapter.payload = {
        'total': 100,
        'page_size': 100,
        'homework_activities': [
          for (var i = 1; i <= 100; i++) {'id': i, 'title': 'Task $i'},
        ],
      };
      expect(await repo.fetchCourseHomework(1), hasLength(100));
      expect(adapter.requests, hasLength(1));
    },
  );
  test(
    'overlapping course readers share one request and can refresh again',
    () async {
      adapter.payload = {
        'homework_activities': [
          {'id': 7, 'title': 'Task'},
        ],
      };
      final gate = Completer<void>();
      adapter.gate = gate.future;
      final first = repo.fetchCourseHomework(1);
      final second = repo.fetchCourseHomework(1);
      gate.complete();
      final results = await Future.wait([first, second]);
      expect(adapter.requests, hasLength(1));
      expect(results.first.single.id, 7);
      expect(results.last.single.id, 7);
      await repo.fetchCourseHomework(1);
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'failed shared request is released; distinct courses stay separate',
    () async {
      adapter.payload = {'error': 'bad payload'};
      final results = [
        repo.fetchCourseHomework(1),
        repo.fetchCourseHomework(1),
      ];
      await Future.wait([
        for (final result in results)
          expectLater(result, throwsFormatException),
      ]);
      expect(adapter.requests, hasLength(1));
      adapter.payload = {
        'homework_activities': [
          {'id': 7, 'title': 'Task'},
        ],
      };
      final fresh = await Future.wait([
        repo.fetchCourseHomework(1),
        repo.fetchCourseHomework(2),
      ]);
      expect(fresh.map((items) => items.single.courseId), [1, 2]);
      expect(adapter.requests, hasLength(3));
    },
  );

  test(
    'session replacement cannot join the previous session request',
    () async {
      adapter.payload = {
        'homework_activities': [
          {'id': 7, 'title': 'Task'},
        ],
      };
      final started = Completer<void>();
      final gate = Completer<void>();
      adapter.gate = gate.future;
      adapter.onRequest = () {
        if (!started.isCompleted) started.complete();
      };
      final first = expectLater(
        repo.fetchCourseHomework(1),
        throwsA(isA<DioException>()),
      );
      await started.future;
      await repo.http.clearSession();
      final second = repo.fetchCourseHomework(1);
      gate.complete();
      await first;
      expect((await second).single.id, 7);
      expect(adapter.requests, hasLength(2));
    },
  );
}
