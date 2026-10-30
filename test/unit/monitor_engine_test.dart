import 'dart:async';
import 'package:dio/dio.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/monitor/monitor_engine.dart';
import 'package:xmu_rollcall/features/monitor/monitor_models.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/monitor/course_watch.dart';

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
  test(
    'long-break polling waits at the next real boundary and skips lectures',
    () async {
      DateTime at(int h, int m) => DateTime(2026, 10, 30, h, m);
      final slots = [
        TimetableSlot(sequence: 1, start: at(9, 0), end: at(9, 45)),
        TimetableSlot(sequence: 2, start: at(10, 15), end: at(11, 0)),
      ];
      final lesson = WatchedLesson(
        'c',
        at(0, 0),
        courseMeetingBlocks(slots).single,
        slots,
      );
      var clock = at(9, 44);
      var requests = 0;
      final updates = <MonitorEngineUpdate>[];
      engine = MonitorEngine(
        config: const MonitorConfig(courseWatch: true, jitterRatio: 0),
        now: () => clock,
        loadDetectionWindow: () async => DetectionWindow(
          enabled: true,
          scheduleBased: true,
          intervals: lesson.ranges,
        ),
        fetch: () async {
          requests++;
          return [];
        },
        notify: (_) async => true,
        onUpdate: updates.add,
      );
      engine.start();
      await engine.pollNow();
      expect(requests, 0);
      expect(updates.last.nextPollAt, at(9, 45));
      for (final time in [at(9, 45), at(9, 59), at(10, 14)]) {
        clock = time;
        await engine.pollNow();
      }
      expect(requests, 3);
      clock = at(10, 15);
      await engine.pollNow();
      expect(requests, 3);
      expect(updates.last.nextPollAt, at(11, 0));
      engine.stop();
    },
  );
  testWidgets('notification-only watch continues without duplicate alerts', (
    tester,
  ) async {
    var fetches = 0, alerts = 0;
    final updates = <MonitorEngineUpdate>[];
    engine = MonitorEngine(
      config: const MonitorConfig(
        courseWatch: true,
        autoAnswer: false,
        jitterRatio: 0,
      ),
      fetch: () async {
        fetches++;
        return [item(1)];
      },
      notify: (_) async {
        alerts++;
        return true;
      },
      now: tester.binding.clock.now,
      onUpdate: updates.add,
    );
    engine.start();
    await engine.pollNow();
    expect(updates.where((u) => u.running == false), isEmpty);
    expect(updates.any((u) => u.message == '已发现待签到活动，处理后继续值守'), isTrue);
    await tester.pump(const Duration(seconds: 20));
    expect(fetches, 2);
    expect(alerts, 1);
    engine.stop();
  });
  testWidgets(
    'a discovered batch finishes waiting after the discovery window closes',
    (tester) async {
      final start = tester.binding.clock.now();
      var fetches = 0, attempts = 0;
      final completed = <int>{};
      engine = MonitorEngine(
        config: const MonitorConfig(
          courseWatch: true,
          autoAnswer: true,
          answerWaitMode: AnswerWaitMode.count,
          jitterRatio: 0,
          attendanceIntervalSeconds: 15,
        ),
        loadDetectionWindow: () async => DetectionWindow(
          enabled: true,
          scheduleBased: true,
          intervals: [
            (start: start, end: start.add(const Duration(seconds: 1))),
          ],
        ),
        loadAutomaticWindow: () async => const DetectionWindow(),
        fetch: () async {
          fetches++;
          return [item(1)];
        },
        notify: (_) async => true,
        processAutomatic: (items, config, current) async {
          if (++attempts == 2) completed.add(1);
          return null;
        },
        completedAutomaticIds: () => completed,
        onUpdate: (_) {},
        now: tester.binding.clock.now,
      );
      engine.start();
      await engine.pollNow();
      await tester.pump(const Duration(seconds: 15));
      expect(completed, {1});
      expect(fetches, 1);
      engine.stop();
    },
  );
  testWidgets('course watch keeps discovering after completing a batch', (
    tester,
  ) async {
    var fetches = 0;
    final completed = <int>{};
    engine = MonitorEngine(
      config: const MonitorConfig(
        courseWatch: true,
        autoAnswer: true,
        answerWaitMode: AnswerWaitMode.none,
        jitterRatio: 0,
      ),
      fetch: () async {
        fetches++;
        return [item(fetches)];
      },
      notify: (_) async => true,
      processAutomatic: (items, config, current) async {
        completed.addAll(items.map((i) => i.rollcallId));
        return '成功';
      },
      completedAutomaticIds: () => completed,
      onUpdate: (_) {},
      now: tester.binding.clock.now,
    );
    engine.start();
    await engine.pollNow();
    await tester.pump(const Duration(seconds: 20));
    expect(fetches, 2);
    expect(completed, {1, 2});
    engine.stop();
  });
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
      expect(discoveries, 2);
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
        intervalSeconds: 10,
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
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 10));
    }
    expect(checks, 1);
    await tester.pump(const Duration(seconds: 10));
    expect(checks, 2);
    independent.stop();
  });

  testWidgets(
    '300-second interval schedules the next discovery at 300 seconds',
    (tester) async {
      var discoveries = 0;
      engine = MonitorEngine(
        config: const MonitorConfig(intervalSeconds: 300, jitterRatio: 0),
        fetch: () async {
          discoveries++;
          return [];
        },
        notify: (_) async => true,
        now: tester.binding.clock.now,
        onUpdate: (_) {},
      );
      engine.start();
      await engine.pollNow();
      expect(discoveries, 1);
      await tester.pump(const Duration(seconds: 299));
      expect(discoveries, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(discoveries, 2);
      engine.stop();
    },
  );

  final now = DateTime(2026, 10, 11, 10);

  testWidgets(
    'discovery hands off a fixed batch, waits independently, then finishes',
    (tester) async {
      var discoveries = 0;
      var checks = 0;
      final completed = <int>{};
      final phases = <MonitorEngineUpdate>[];
      final batches = <List<int>>[];
      final validity = <bool>[];
      engine = MonitorEngine(
        config: const MonitorConfig(
          autoAnswer: true,
          intervalSeconds: 10,
          jitterRatio: 0,
          attendanceIntervalSeconds: 15,
        ),
        fetch: () async {
          discoveries++;
          return [item(1)];
        },
        notify: (_) async => true,
        completedAutomaticIds: () => completed,
        processAutomatic: (items, _, current) async {
          batches.add(items.map((i) => i.rollcallId).toList());
          validity.add(current());
          if (++checks == 3) completed.add(1);
          return checks == 3 ? 'signed' : 'waiting';
        },
        now: tester.binding.clock.now,
        onUpdate: phases.add,
      );
      engine.start();
      await engine.pollNow();
      expect(
        phases.any((u) => u.discovering == false && u.running == true),
        isTrue,
      );
      expect(checks, 1);
      await engine.pollNow();
      await tester.pump(const Duration(seconds: 15));
      expect(checks, 2, reason: phases.map((u) => u.message).join('|'));
      await tester.pump(const Duration(seconds: 15));
      expect(checks, 3);
      expect(batches, [
        [1],
        [1],
        [1],
      ]);
      expect(validity, everyElement(isTrue));
      expect(phases.last.running, isFalse);
      expect(
        phases.where((u) => u.items != null).last.items!.single.isAnswered,
        isTrue,
      );
      await tester.pump(const Duration(minutes: 2));
      expect(discoveries, 1);
      expect(checks, 3);
    },
  );

  testWidgets('no-wait automatic retry also survives discovery stopping', (
    tester,
  ) async {
    var checks = 0;
    final completed = <int>{};
    engine = MonitorEngine(
      config: const MonitorConfig(
        autoAnswer: true,
        answerWaitMode: AnswerWaitMode.none,
        attendanceIntervalSeconds: 15,
      ),
      fetch: () async => [item(1)],
      notify: (_) async => true,
      completedAutomaticIds: () => completed,
      processAutomatic: (_, _, _) async {
        if (++checks == 2) completed.add(1);
        return 'retry';
      },
      now: tester.binding.clock.now,
      onUpdate: (_) {},
    );
    engine.start();
    await engine.pollNow();
    await tester.pump(const Duration(seconds: 14));
    expect(checks, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(checks, 2);
    await tester.pump(const Duration(minutes: 1));
    expect(checks, 2);
  });

  testWidgets('explicit stop cancels the automatic handoff timer too', (
    tester,
  ) async {
    var checks = 0;
    engine = MonitorEngine(
      config: const MonitorConfig(autoAnswer: true),
      fetch: () async => [item(1)],
      notify: (_) async => true,
      processAutomatic: (_, _, _) async {
        checks++;
        return 'waiting';
      },
      now: tester.binding.clock.now,
      onUpdate: (_) {},
    );
    engine.start();
    await engine.pollNow();
    engine.stop();
    await tester.pump(const Duration(minutes: 2));
    expect(checks, 1);
  });

  testWidgets('restoring a handed-off batch never restarts discovery', (
    tester,
  ) async {
    var discoveries = 0;
    var checks = 0;
    final completed = <int>{};
    engine = MonitorEngine(
      config: const MonitorConfig(autoAnswer: true),
      fetch: () async {
        discoveries++;
        return [item(99)];
      },
      notify: (_) async => true,
      completedAutomaticIds: () => completed,
      processAutomatic: (items, _, _) async {
        checks++;
        completed.add(items.single.rollcallId);
        return 'signed';
      },
      now: tester.binding.clock.now,
      onUpdate: (_) {},
    );
    engine.start(handedOffItems: [item(1)]);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(discoveries, 0);
    expect(checks, 1);
    expect(completed, {1});
  });
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

  test(
    'discovery ends after a pending batch; explicit restart finds new ids',
    () async {
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
      engine.start();
      await engine.pollNow();
      expect(alerts, [
        [1],
        [2],
      ]);
      expect(engine.notifiedIds, {1, 2});
      expect(updates.last.running, isFalse);
    },
  );

  test(
    'failed notification can retry after explicit restart without repeating discovery',
    () async {
      var attempts = 0;
      create(
        fetch: () async => [item(1)],
        notify: (_) async => ++attempts > 1,
      ).start();
      await engine.pollNow();
      expect(engine.notifiedIds, isEmpty);
      engine.start();
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
