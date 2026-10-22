import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';

void main() {
  test('slow background request does not block another request', () async {
    final limiter = RateLimiter(minInterval: Duration.zero, maxConcurrent: 2);
    final slow = Completer<int>();
    final first = limiter.schedule(() => slow.future);
    expect(await limiter.schedule(() async => 2), 2);
    slow.complete(1);
    expect(await first, 1);
  });

  test(
    'queued submission runs before background work with bounded concurrency',
    () async {
      final limiter = RateLimiter(minInterval: Duration.zero, maxConcurrent: 1);
      final slow = Completer<void>();
      final order = <String>[];
      final first = limiter.schedule(() => slow.future);
      final background = limiter.schedule(() async {
        order.add('background');
      }, priority: RequestPriority.background);
      final submission = limiter.schedule(() async {
        order.add('submission');
      }, priority: RequestPriority.submission);
      slow.complete();
      await Future.wait([first, background, submission]);
      expect(order, ['submission', 'background']);
    },
  );

  test(
    'cancelling queued work never executes it and leaves queue usable',
    () async {
      final limiter = RateLimiter(minInterval: Duration.zero, maxConcurrent: 1);
      final slow = Completer<void>();
      final first = limiter.schedule(() => slow.future);
      final token = CancelToken();
      var called = false;
      final pending = limiter.schedule(() async {
        called = true;
      }, cancelToken: token);
      final check = expectLater(
        pending,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      token.cancel();
      await check;
      slow.complete();
      await first;
      expect(await limiter.schedule(() async => 3), 3);
      expect(called, isFalse);
    },
  );

  test(
    'foreground starts while background work waits for reserved budget',
    () async {
      final limiter = RateLimiter(
        maxPerMinute: 3,
        foregroundReserve: 1,
        maxConcurrent: 3,
        minInterval: Duration.zero,
        window: const Duration(seconds: 1),
      );
      await limiter.schedule(() async {}, priority: RequestPriority.background);
      await limiter.schedule(() async {}, priority: RequestPriority.background);
      final token = CancelToken();
      var ran = false;
      final background = limiter.schedule(
        () async {
          ran = true;
        },
        priority: RequestPriority.background,
        cancelToken: token,
      );
      final cancelled = expectLater(background, throwsA(isA<DioException>()));
      expect(
        await limiter
            .schedule(() async => 'foreground')
            .timeout(const Duration(milliseconds: 300)),
        'foreground',
      );
      expect(ran, isFalse);
      token.cancel();
      await cancelled;
    },
  );

  test('background concurrency leaves a slot for interactive work', () async {
    final limiter = RateLimiter(maxConcurrent: 2, minInterval: Duration.zero);
    final release = Completer<void>();
    final entered = Completer<void>();
    final first = limiter.schedule(() {
      entered.complete();
      return release.future;
    }, priority: RequestPriority.background);
    await entered.future;
    var queuedRan = false;
    final queued = limiter.schedule(() async {
      queuedRan = true;
    }, priority: RequestPriority.background);
    expect(await limiter.schedule(() async => 7), 7);
    expect(queuedRan, isFalse);
    release.complete();
    await Future.wait([first, queued]);
  });

  test('start spacing applies across concurrent requests', () async {
    final limiter = RateLimiter(minInterval: const Duration(milliseconds: 30));
    final starts = <DateTime>[];
    await Future.wait(
      List.generate(
        3,
        (_) => limiter.schedule(() async {
          starts.add(DateTime.now());
        }),
      ),
    );
    expect(
      starts[1].difference(starts[0]).inMilliseconds,
      greaterThanOrEqualTo(25),
    );
    expect(
      starts[2].difference(starts[1]).inMilliseconds,
      greaterThanOrEqualTo(25),
    );
  });
}
