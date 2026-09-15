import 'dart:async';
import 'dart:collection';

/// Simple global request gate: max [maxPerMinute] starts, plus optional spacing.
class RateLimiter {
  RateLimiter({
    this.maxPerMinute = 30,
    this.minInterval = const Duration(milliseconds: 200),
  });

  final int maxPerMinute;
  final Duration minInterval;

  final Queue<DateTime> _starts = Queue<DateTime>();
  DateTime? _lastStart;
  Future<void> _chain = Future.value();

  Future<T> schedule<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _chain = _chain.then((_) async {
      try {
        await _waitSlot();
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> _waitSlot() async {
    while (true) {
      final now = DateTime.now();
      while (_starts.isNotEmpty &&
          now.difference(_starts.first) > const Duration(minutes: 1)) {
        _starts.removeFirst();
      }
      final last = _lastStart;
      final needSpacing = last != null && now.difference(last) < minInterval;
      final atCap = _starts.length >= maxPerMinute;
      if (!needSpacing && !atCap) {
        _lastStart = now;
        _starts.addLast(now);
        return;
      }
      final waitSpacing = needSpacing
          ? minInterval - now.difference(last)
          : Duration.zero;
      final waitRpm = atCap
          ? const Duration(minutes: 1) - now.difference(_starts.first)
          : Duration.zero;
      final wait = waitSpacing > waitRpm ? waitSpacing : waitRpm;
      await Future<void>.delayed(
        wait < const Duration(milliseconds: 50)
            ? const Duration(milliseconds: 50)
            : wait,
      );
    }
  }
}
