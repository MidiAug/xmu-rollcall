import 'dart:async';
import 'package:dio/dio.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/monitor/monitor_engine.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

RollcallItem item(int id) => RollcallItem(
  rollcallId: id,
  courseTitle: '测试课',
  createdByName: '老师',
  type: RollcallType.number,
  status: 'on_call',
  rollcallStatus: 'on_call',
  isExpired: false,
  scored: false,
);

void main() {
  late MonitorEngine engine;
  testWidgets(
    'a completed first event never suppresses a second in the same course',
    (tester) async {
      final first = RollcallItem.fromJson({
        ...item(1).toMonitorJson(),
        'course_id': 'a',
        'status': 'on_call_fine',
      });
      final second = RollcallItem.fromJson({
        ...item(2).toMonitorJson(),
        'course_id': 'a',
      });
      var snapshot = [first];
      var discoveries = 0;
      final alerts = <List<int>>[];
      List<RollcallItem>? published;
      engine = MonitorEngine(
        config: const MonitorConfig(intervalSeconds: 120, jitterRatio: 0),
        fetch: () async {
          discoveries++;
          return snapshot;
        },
        notify: (items) async {
          alerts.add(items.map((i) => i.rollcallId).toList());
          return true;
        },
        onUpdate: (update) {
          if (update.items != null) published = update.items;
        },
        now: tester.binding.clock.now,
      );
      engine.start();
      await engine.pollNow();
      snapshot = [first, second];
      await tester.pump(const Duration(seconds: 119));
      expect(discoveries, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(discoveries, 2);
      expect(published!.map((i) => i.rollcallId), [1, 2]);
      expect(alerts, [
        [2],
      ]);
      await tester.pump(const Duration(seconds: 120));
      expect(discoveries, 3);
      expect(alerts, [
        [2],
      ]);
      engine.stop();
    },
  );
  testWidgets('attendance checks use their own interval between discoveries', (
    tester,
  ) async {
    var discoveries = 0;
    var checks = 0;
    final independent = engine = MonitorEngine(
      config: const MonitorConfig(
        autoAnswer: true,
        intervalSeconds: 60,
        jitterRatio: 0,
        attendanceIntervalSeconds: 15,
      ),
      fetch: () async {
        discoveries++;
        return [item(1)];
      },
      notify: (_) async => true,
      processAutomatic: (_, _, _) async {
        checks++;
        return 'waiting';
      },
      now: tester.binding.clock.now,
      onUpdate: (_) {},
    );
    independent.start();
    await independent.pollNow();
    expect(discoveries, 1);
    expect(checks, 1);
    await tester.pump(const Duration(seconds: 15));
    expect(discoveries, 1);
    expect(checks, 2);
    independent.updateConfig(const MonitorConfig(autoAnswer: false));
    await tester.pump(const Duration(seconds: 15));
    expect(checks, 2);
    independent.stop();
  });

  testWidgets('frequent discovery does not bypass the attendance interval', (
    tester,
  ) async {
    var checks = 0;
    final independent = engine = MonitorEngine(
      config: const MonitorConfig(
        autoAnswer: true,
        intervalSeconds: 15,
        jitterRatio: 0,
        attendanceIntervalSeconds: 60,
      ),
      fetch: () async => [item(1)],
      notify: (_) async => true,
      processAutomatic: (_, _, _) async {
        checks++;
        return null;
      },
      now: tester.binding.clock.now,
      onUpdate: (_) {},
    );
    independent.start();
    await independent.pollNow();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 15));
    expect(checks, 1);
    await tester.pump(const Duration(seconds: 15));
    expect(checks, 2);
    independent.stop();
  });

  final now = DateTime(2026, 10, 11, 10);
  final updates = <MonitorEngineUpdate>[];
  setUp(updates.clear);
  tearDown(() => engine.stop());
  MonitorEngine create({
    required Future<List<RollcallItem>> Function() fetch,
    Future<bool> Function(List<RollcallItem>)? notify,
    Set<int> notified = const {},
  }) {
    return engine = MonitorEngine(
      config: const MonitorConfig(intervalSeconds: 20, jitterRatio: 0),
      fetch: fetch,
      notify: notify ?? (_) async => true,
      onUpdate: updates.add,
      now: () => now,
      notifiedIds: notified,
    );
  }

  test('failed request is a failure and applies backoff', () async {
    create(fetch: () async => throw StateError('offline')).start();
    await engine.pollNow();
    expect(updates.where((u) => u.ok == false).single.failures, 1);
    expect(updates.last.nextPollAt, now.add(const Duration(seconds: 40)));
    await engine.pollNow();
    expect(updates.last.failures, 2);
    expect(updates.last.nextPollAt, now.add(const Duration(seconds: 80)));
  });

  test('successfully empty response resets previous failures', () async {
    var fail = true;
    create(
      fetch: () async {
        if (fail) throw StateError('offline');
        return [];
      },
    ).start();
    await engine.pollNow();
    fail = false;
    await engine.pollNow();
    expect(updates.last.failures, 0);
    expect(updates.last.nextPollAt, now.add(const Duration(seconds: 20)));
    expect(updates.where((u) => u.ok == true).single.count, 0);
  });

  test('keeps polling after discovery and alerts only for new ids', () async {
    var items = [item(1)];
    final alerts = <List<int>>[];
    create(
      fetch: () async => items,
      notify: (items) async {
        alerts.add(items.map((i) => i.rollcallId).toList());
        return true;
      },
    ).start();
    await engine.pollNow();
    await engine.pollNow();
    items = [item(1), item(2)];
    await engine.pollNow();
    expect(alerts, [
      [1],
      [2],
    ]);
    expect(engine.notifiedIds, {1, 2});
    expect(updates.last.nextPollAt, isNotNull);
  });

  test(
    'failed notification is retried instead of being deduplicated',
    () async {
      var attempts = 0;
      create(
        fetch: () async => [item(1)],
        notify: (_) async => ++attempts > 1,
      ).start();
      await engine.pollNow();
      expect(engine.notifiedIds, isEmpty);
      await engine.pollNow();
      expect(attempts, 2);
      expect(engine.notifiedIds, {1});
      expect(updates.last.failures, 0);
    },
  );

  test('restored notified ids do not alert again', () async {
    var alerts = 0;
    create(
      fetch: () async => [item(1)],
      notified: {1},
      notify: (_) async {
        alerts++;
        return true;
      },
    ).start();
    await engine.pollNow();
    expect(alerts, 0);
  });

  test(
    'pollNow during a request does not create overlapping requests',
    () async {
      final pending = Completer<List<RollcallItem>>();
      var requests = 0;
      create(
        fetch: () {
          requests++;
          return pending.future;
        },
      ).start();
      final first = engine.pollNow();
      await engine.pollNow();
      expect(requests, 1);
      pending.complete([]);
      await first;
    },
  );

  test(
    'stop discards in-flight success without notification or state writes',
    () async {
      final pending = Completer<List<RollcallItem>>();
      var alerts = 0;
      create(
        fetch: () => pending.future,
        notify: (_) async {
          alerts++;
          return true;
        },
      ).start();
      final poll = engine.pollNow();
      engine.stop();
      final count = updates.length;
      pending.complete([item(1)]);
      await poll;
      expect(alerts, 0);
      expect(updates.length, count);
    },
  );

  test('stop and restart discard old request errors', () async {
    final pending = Completer<List<RollcallItem>>();
    create(fetch: () => pending.future).start();
    final poll = engine.pollNow();
    engine.stop();
    engine.start();
    pending.completeError(StateError('old request'));
    await poll;
    expect(updates.where((u) => u.ok == false), isEmpty);
    expect(updates.last.failures, 0);
  });

  test('configuration can change without restarting the task', () async {
    create(fetch: () async => []).start();
    await engine.pollNow();
    engine.updateConfig(
      const MonitorConfig(intervalSeconds: 60, jitterRatio: 0),
    );
    expect(updates.last.nextPollAt, now.add(const Duration(seconds: 60)));
  });

  test(
    'empty discovery is published to clear previously visible tasks',
    () async {
      create(fetch: () async => []).start();
      await engine.pollNow();
      expect(updates.singleWhere((u) => u.ok == true).items, isEmpty);
    },
  );

  test('session expiry stops polling and asks for login', () async {
    var calls = 0;
    create(
      fetch: () async {
        calls++;
        final options = RequestOptions(path: '/rollcalls');
        throw DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 401),
        );
      },
    ).start();
    await engine.pollNow();
    expect(updates.last.sessionExpired, isTrue);
    await engine.pollNow();
    expect(calls, 1);
  });
}
