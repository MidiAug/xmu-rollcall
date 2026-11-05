import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_batch.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_csv.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_models.dart';
import '../fixtures/ta_http_fixture.dart';

void main() {
  const students = [
    TaStudent(id: 1, number: '0001', name: 'A', submitted: true),
    TaStudent(id: 2, number: '0002', name: 'B', submitted: true),
    TaStudent(id: 3, number: '0003', name: 'C'),
  ];
  testWidgets('only successive real writes wait an additional 200 to 500 ms', (
    tester,
  ) async {
    final f = TaHttpFixture();
    final repo = await f.repository();
    addTearDown(repo.dispose);
    repo.http.dio.transformer = SyncTransformer();
    final rows = parseTaCsv('user_no,score\n0001,80\n0002,90', students);
    final times = <DateTime>[];
    f.intercept = (r) async {
      if (r.method == 'PUT') times.add(tester.binding.clock.now());
      return null;
    };
    final run = TaGradeBatch().run(
      repository: repo,
      activityId: 81,
      rows: rows,
      overwrite: true,
      allowUnsubmitted: false,
      onChanged: () {},
    );
    await tester.pump(Duration.zero);
    expect(rows.first.status, TaRowStatus.saved);
    expect(times, hasLength(1));
    await tester.pump(const Duration(milliseconds: 199));
    expect(times, hasLength(1));
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump(Duration.zero);
    await run;
    expect(times, hasLength(2));
    expect(
      times[1].difference(times[0]).inMilliseconds,
      inInclusiveRange(200, 500),
    );
    expect(rows.every((r) => r.status == TaRowStatus.saved), isTrue);
  });
  for (final cancel in [false, true]) {
    testWidgets(
      'stop or identity loss during row delay prevents next PUT cancel=$cancel',
      (tester) async {
        final f = TaHttpFixture();
        final repo = await f.repository();
        addTearDown(repo.dispose);
        repo.http.dio.transformer = SyncTransformer();
        final rows = parseTaCsv('user_no,score\n0001,80\n0002,90', students);
        final batch = TaGradeBatch();
        final run = batch.run(
          repository: repo,
          activityId: 81,
          rows: rows,
          overwrite: true,
          allowUnsubmitted: false,
          onChanged: () {},
        );
        await tester.pump(Duration.zero);
        expect(rows.first.status, TaRowStatus.saved);
        if (cancel) {
          repo.dispose();
        } else {
          batch.stop();
        }
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(Duration.zero);
        await run;
        expect(f.requests.where((r) => r.method == 'PUT'), hasLength(1));
        expect(rows.last.status, TaRowStatus.ready);
      },
    );
  }
  testWidgets('same-score and unsubmitted rows do not add a trailing delay', (
    tester,
  ) async {
    final f = TaHttpFixture()..scores[2] = 90;
    final repo = await f.repository();
    addTearDown(repo.dispose);
    repo.http.dio.transformer = SyncTransformer();
    final rows = parseTaCsv(
      'user_no,score\n0001,80\n0002,90\n0003,90',
      students,
    );
    var complete = false;
    final run = TaGradeBatch()
        .run(
          repository: repo,
          activityId: 81,
          rows: rows,
          overwrite: true,
          allowUnsubmitted: false,
          onChanged: () {},
        )
        .then((_) => complete = true);
    await tester.pump(Duration.zero);
    expect(complete, isTrue);
    await run;
    expect(rows.map((r) => r.status), [
      TaRowStatus.saved,
      TaRowStatus.skipped,
      TaRowStatus.skipped,
    ]);
    expect(f.requests.where((r) => r.method == 'PUT'), hasLength(1));
  });
}
