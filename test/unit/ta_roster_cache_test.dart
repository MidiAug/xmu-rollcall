import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_models.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_roster_store.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_repository.dart';
import '../fixtures/ta_http_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final at = DateTime(2026, 11, 5, 9);
  final snapshot = TaRosterSnapshot(const [
    TaStudent(
      id: 1,
      number: '0001',
      name: '示例甲',
      submitted: true,
      score: 0,
      scoreChecked: true,
    ),
    TaStudent(id: 2, number: '0002', name: '示例乙', scoreChecked: true),
  ], at);
  test(
    'cold restart restores scores before authentication and isolates all scope keys',
    () async {
      await TaRosterStore(11).write(91, 81, snapshot);
      expect(await TaRosterStore(22).read(91, 81), isNull);
      expect(await TaRosterStore(11).read(92, 81), isNull);
      expect(await TaRosterStore(11).read(91, 82), isNull);
      final f = TaHttpFixture();
      final base = await f.repository();
      addTearDown(base.dispose);
      var prepared = false;
      final repo = TaGradingRepository(
        base.http,
        cacheUserId: 11,
        prepareSession: () async {
          prepared = true;
        },
      );
      final cached = await repo.restoreStudents(91, 81);
      expect(cached!.students.map((s) => s.score), [0, null]);
      expect(cached.students.first.number, '0001');
      expect(cached.checkedAt, at);
      expect(prepared, isFalse);
      expect(f.requests, isEmpty);
      repo.dispose();
      final other = TaGradingRepository(base.http, cacheUserId: 22);
      addTearDown(other.dispose);
      expect(await other.restoreStudents(91, 81), isNull);
      await JsonDiskCache.clearAll();
      expect(await TaRosterStore(11).read(91, 81), isNull);
    },
  );
  test('unreadable or duplicate cache rows are discarded as a whole', () async {
    for (final rows in [
      [
        {
          'id': 1,
          'number': '0001',
          'name': 'A',
          'submitted': true,
          'score': 'NaN',
        },
      ],
      [
        {'id': 1, 'number': 1, 'name': 'A', 'submitted': true},
      ],
      [
        {'id': 1, 'number': '1', 'name': 'A', 'submitted': false},
        {'id': 1, 'number': '2', 'name': 'B', 'submitted': false},
      ],
    ]) {
      await JsonDiskCache.writeList(
        'ta_roster_v1_11_91_81',
        rows,
        fetchedAt: at,
      );
      expect(await TaRosterStore(11).read(91, 81), isNull);
    }
  });
  test(
    'a malformed envelope member cannot silently shorten a student roster',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        JsonDiskCache.key('ta_roster_v1_11_91_81'),
        jsonEncode({
          'fetchedAt': at.toIso8601String(),
          'items': [
            {'id': 1, 'number': '0001', 'name': 'A', 'submitted': true},
            null,
          ],
        }),
      );
      expect(await TaRosterStore(11).read(91, 81), isNull);
    },
  );
  test(
    'bulk refresh keeps the previous mirror until all grades arrive and on failure',
    () async {
      final f = TaHttpFixture()..scores[1] = 88;
      final base = await f.repository();
      addTearDown(base.dispose);
      final repo = TaGradingRepository(base.http, cacheUserId: 11);
      addTearDown(repo.dispose);
      await repo.cacheStudents(91, 81, snapshot.students, checkedAt: at);
      final gate = Completer<void>();
      final entered = Completer<void>();
      f.intercept = (r) async {
        if (r.uri.path.endsWith('/homework-scores')) {
          entered.complete();
          await gate.future;
        }
        return null;
      };
      final refresh = repo.students(91, 81);
      await entered.future;
      expect((await repo.restoreStudents(91, 81))!.students.first.score, 0);
      gate.complete();
      final fresh = await refresh;
      expect(fresh.first.score, 88);
      expect(fresh.every((s) => s.scoreChecked), isTrue);
      await repo.cacheStudents(91, 81, fresh, checkedAt: at);
      f.intercept = (r) async => r.uri.path.endsWith('/homework-scores')
          ? TaHttpFixture.response({}, 403)
          : null;
      await expectLater(repo.students(91, 81), throwsException);
      final kept = await repo.restoreStudents(91, 81);
      expect(kept!.students.first.score, 88);
      expect(kept.checkedAt, at);
      expect(f.requests.where((r) => r.method != 'GET'), isEmpty);
    },
  );
  test(
    'batch score cache update preserves attachments and full-refresh time',
    () async {
      final f = TaHttpFixture();
      final base = await f.repository();
      addTearDown(base.dispose);
      final repo = TaGradingRepository(base.http, cacheUserId: 11);
      addTearDown(repo.dispose);
      await repo.cacheStudents(91, 81, const [
        TaStudent(
          id: 1,
          number: '0001',
          name: 'A',
          submitted: true,
          attachmentBytes: 1048576,
        ),
        TaStudent(
          id: 2,
          number: '0002',
          name: 'B',
          submitted: true,
          attachmentBytes: 0,
        ),
        TaStudent(
          id: 3,
          number: '0003',
          name: 'C',
          score: 60,
          scoreChecked: true,
        ),
      ], checkedAt: at);
      await repo.cacheStudentScores(91, 81, {1: 80, 2: 90});
      final disk = await TaRosterStore(11).read(91, 81);
      expect(disk!.checkedAt, at);
      expect(disk.students.map((s) => s.score), [80, 90, 60]);
      expect(disk.students.map((s) => s.attachmentBytes), [1048576, 0, null]);
      expect(disk.students.map((s) => s.number), ['0001', '0002', '0003']);
    },
  );
}
