import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/cache/remote_course_cache.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_assignment_store.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_models.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_repository.dart';
import '../fixtures/ta_http_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final at = DateTime(2026, 11, 4, 9);
  final snapshot = TaAssignmentSnapshot(const [
    TaAssignment(
      id: 81,
      title: '缓存作业',
      expected: 111,
      submitted: 47,
      graded: 3,
      canGrade: true,
    ),
  ], at);

  test(
    'restart restores complete summaries without authentication or HTTP',
    () async {
      final f = TaHttpFixture();
      final base = await f.repository();
      addTearDown(base.dispose);
      final first = TaGradingRepository(
        base.http,
        cacheUserId: 11,
        now: () => at,
      );
      await first.assignments(91);
      first.dispose();
      var preparations = 0;
      final cold = TaGradingRepository(
        base.http,
        cacheUserId: 11,
        now: () => at,
        prepareSession: () async {
          preparations++;
        },
      );
      addTearDown(cold.dispose);
      await cold.restoreAssignments(91);
      expect(cold.cachedAssignments(91)!.checkedAt, at);
      expect((await cold.assignments(91)).single.title, TaHttpFixture.title);
      expect(f.requests, hasLength(1));
      expect(preparations, 0);
      expect(cold.cachedAssignments(91)!.items.single.canGrade, isFalse);
    },
  );

  test(
    'different owner IDs and courses cannot read or overwrite each other',
    () async {
      await TaAssignmentStore(11).write(91, snapshot);
      expect(await TaAssignmentStore(22).read(91), isNull);
      expect(await TaAssignmentStore(11).read(92), isNull);
      await TaAssignmentStore(22).write(91, TaAssignmentSnapshot(const [], at));
      expect(
        (await TaAssignmentStore(11).read(91))!.items.single.title,
        '缓存作业',
      );
      expect((await TaAssignmentStore(22).read(91))!.items, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(
        JsonDiskCache.key('ta_assignments_v1_11_91'),
      )!;
      expect(raw, isNot(contains('canGrade')));
      expect(raw, isNot(contains('score')));
      await clearRemoteCourseCache();
      expect(await TaAssignmentStore(11).read(91), isNull);
      expect(await TaAssignmentStore(22).read(91), isNull);
    },
  );

  test(
    'expired disk data survives failed auth and successful retry replaces disk time',
    () async {
      await TaAssignmentStore(11).write(91, snapshot);
      final f = TaHttpFixture();
      final base = await f.repository();
      addTearDown(base.dispose);
      var now = at.add(const Duration(minutes: 3));
      var attempts = 0;
      final repo = TaGradingRepository(
        base.http,
        cacheUserId: 11,
        now: () => now,
        prepareSession: () async {
          if (++attempts == 1) throw StateError('暂时离线');
        },
      );
      addTearDown(repo.dispose);
      await repo.restoreAssignments(91);
      expect(attempts, 0);
      await expectLater(repo.assignments(91), throwsStateError);
      expect(repo.cachedAssignments(91)!.checkedAt, at);
      expect((await TaAssignmentStore(11).read(91))!.checkedAt, at);
      now = now.add(const Duration(seconds: 5));
      f.intercept = (_) async =>
          TaHttpFixture.response({'pages': 1, 'homework_activities': []});
      expect(await repo.assignments(91), isEmpty);
      expect(attempts, 2);
      final disk = (await TaAssignmentStore(11).read(91))!;
      expect(disk.items, isEmpty);
      expect(disk.checkedAt, now);
    },
  );

  test(
    'invalid nested records and duplicate IDs are a full cache miss',
    () async {
      final row = {
        'id': 81,
        'title': '作业',
        'expected': 1,
        'submitted': 0,
        'graded': 0,
      };
      for (final records in [
        [row, 'bad row'],
        [row, row],
        [
          row,
          {...row, 'id': 82, 'graded': 'bad'},
        ],
      ]) {
        await JsonDiskCache.writeList('ta_assignments_v1_11_91', [
          {'course_id': 91, 'assignments': records},
        ], fetchedAt: at);
        expect(await TaAssignmentStore(11).read(91), isNull);
      }
    },
  );

  test('cancelled refresh cannot replace the previous disk snapshot', () async {
    await TaAssignmentStore(11).write(91, snapshot);
    final f = TaHttpFixture();
    final base = await f.repository();
    addTearDown(base.dispose);
    final repo = TaGradingRepository(
      base.http,
      cacheUserId: 11,
      now: () => at.add(const Duration(minutes: 3)),
    );
    await repo.restoreAssignments(91);
    final response = Completer<ResponseBody>();
    final started = Completer<void>();
    f.intercept = (_) {
      started.complete();
      return response.future;
    };
    final request = repo.assignments(91);
    final failed = expectLater(
      request,
      throwsA(anyOf(isA<DioException>(), isA<StateError>())),
    );
    await started.future;
    repo.dispose();
    response.complete(
      TaHttpFixture.response({'pages': 1, 'homework_activities': []}),
    );
    await failed;
    expect((await TaAssignmentStore(11).read(91))!.items.single.title, '缓存作业');
    expect((await TaAssignmentStore(11).read(91))!.checkedAt, at);
  });

  test(
    'detail fork shares prepared revision but external session replacement invalidates both',
    () async {
      final base = await TaHttpFixture().repository();
      addTearDown(base.dispose);
      final repo = TaGradingRepository(
        base.http,
        prepareSession: () => base.http.clearSession(),
      );
      addTearDown(repo.dispose);
      final detail = repo.fork();
      addTearDown(detail.dispose);
      await detail.detail(91, 81);
      expect(repo.active, isTrue);
      expect(detail.active, isTrue);
      await base.http.clearSession();
      expect(repo.active, isFalse);
      expect(detail.active, isFalse);
    },
  );
}
