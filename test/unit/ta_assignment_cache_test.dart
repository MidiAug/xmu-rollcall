import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_repository.dart';
import '../fixtures/ta_http_fixture.dart';

void main() {
  test(
    'course summaries reuse fresh cache, merge requests and expire on demand',
    () async {
      final f = TaHttpFixture();
      final base = await f.repository();
      var now = DateTime(2026, 11, 4, 9);
      final repo = TaGradingRepository(base.http, now: () => now);
      addTearDown(repo.dispose);
      addTearDown(base.dispose);
      final first = repo.assignments(91);
      expect(repo.assignments(91), same(first));
      final items = await first;
      expect(await repo.assignments(91), same(items));
      expect(f.requests, hasLength(1));
      expect(repo.cachedAssignments(92), isNull);
      now = now.add(const Duration(minutes: 2));
      await repo.assignments(91);
      expect(f.requests, hasLength(2));
      expect(repo.cachedAssignments(91)!.checkedAt, now);
      repo.markAssignmentsStale(91);
      await repo.assignments(91);
      expect(f.requests, hasLength(3));
    },
  );

  test(
    'failed refresh keeps snapshot and success time, short throttle precedes HTTP',
    () async {
      final f = TaHttpFixture();
      final base = await f.repository();
      var now = DateTime(2026, 11, 4, 9);
      final repo = TaGradingRepository(base.http, now: () => now);
      addTearDown(repo.dispose);
      addTearDown(base.dispose);
      await repo.assignments(91);
      final old = repo.cachedAssignments(91);
      await repo.assignments(91, refresh: true);
      expect(f.requests, hasLength(1));
      now = now.add(const Duration(seconds: 5));
      f.intercept = (_) async => TaHttpFixture.response({'pages': 'bad'});
      await expectLater(
        repo.assignments(91, refresh: true),
        throwsFormatException,
      );
      expect(repo.cachedAssignments(91), same(old));
      final requests = f.requests.length;
      await repo.assignments(91, refresh: true);
      expect(f.requests.length, requests);
      now = now.add(const Duration(seconds: 5));
      f.intercept = (_) async =>
          TaHttpFixture.response({'pages': 1, 'homework_activities': []});
      expect(await repo.assignments(91, refresh: true), isEmpty);
      expect(repo.cachedAssignments(91)!.items, isEmpty);
      expect(repo.cachedAssignments(91)!.checkedAt, now);
    },
  );

  test(
    'incomplete pagination never overwrites a complete cached course',
    () async {
      final f = TaHttpFixture();
      final base = await f.repository();
      var now = DateTime(2026, 11, 4, 9);
      final repo = TaGradingRepository(base.http, now: () => now);
      addTearDown(repo.dispose);
      addTearDown(base.dispose);
      await repo.assignments(91);
      final old = repo.cachedAssignments(91);
      now = now.add(const Duration(minutes: 3));
      f.intercept = (request) async => TaHttpFixture.response(
        request.uri.queryParameters['page'] == '1'
            ? {
                'pages': 2,
                'homework_activities': [
                  {...f.assignment, 'id': 82},
                ],
              }
            : {'pages': -1},
      );
      await expectLater(repo.assignments(91), throwsFormatException);
      expect(repo.cachedAssignments(91), same(old));
    },
  );

  test(
    'disposed session cannot return cache or publish an in-flight response',
    () async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      addTearDown(repo.dispose);
      final response = Completer<ResponseBody>();
      final started = Completer<void>();
      f.intercept = (_) {
        started.complete();
        return response.future;
      };
      final pending = repo.assignments(91);
      final failed = expectLater(
        pending,
        throwsA(anyOf(isA<DioException>(), isA<StateError>())),
      );
      await started.future;
      repo.dispose();
      response.complete(
        TaHttpFixture.response({
          'pages': 1,
          'homework_activities': [f.assignment],
        }),
      );
      await failed;
      expect(repo.cachedAssignments(91), isNull);
      await expectLater(repo.assignments(91), throwsStateError);
    },
  );
}
