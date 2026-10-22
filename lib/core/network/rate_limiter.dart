import 'dart:async';
import 'dart:collection';
import 'package:dio/dio.dart';

enum RequestPriority { background, normal, submission }

/// Shared start-rate gate with bounded concurrency and priority for submissions.
class RateLimiter {
  RateLimiter({
    this.maxPerMinute = 30,
    this.minInterval = const Duration(milliseconds: 200),
    this.maxConcurrent = 3,
  }) : assert(maxPerMinute > 0),
       assert(maxConcurrent > 0);
  final int maxPerMinute;
  final Duration minInterval;
  final int maxConcurrent;
  final Queue<DateTime> _starts = Queue<DateTime>();
  final List<_PendingRequest> _pending = [];
  DateTime? _lastStart;
  Future<void> _gate = Future.value();
  int _active = 0;

  Future<T> schedule<T>(
    Future<T> Function() action, {
    RequestPriority priority = RequestPriority.normal,
    CancelToken? cancelToken,
  }) {
    final result = Completer<T>();
    final request = _PendingRequest(priority, () async {
      try {
        await waitForStart(cancelToken: cancelToken);
        final value = await action();
        if (!result.isCompleted) result.complete(value);
      } catch (error, stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      }
    });
    if (cancelToken != null) {
      unawaited(
        cancelToken.whenCancel.then((error) {
          _pending.remove(request);
          if (!result.isCompleted) result.completeError(error);
        }),
      );
    }
    _pending.add(request);
    _drain();
    return result.future;
  }

  void _drain() {
    while (_active < maxConcurrent && _pending.isNotEmpty) {
      var index = 0;
      for (var i = 1; i < _pending.length; i++) {
        if (_pending[i].priority.index > _pending[index].priority.index) {
          index = i;
        }
      }
      final request = _pending.removeAt(index);
      _active++;
      unawaited(
        request.run().whenComplete(() {
          _active--;
          _drain();
        }),
      );
    }
  }

  /// Retries share the start budget without taking a second concurrency slot.
  Future<void> waitForStart({CancelToken? cancelToken}) {
    final result = _gate.then((_) => _waitSlot(cancelToken));
    _gate = result.catchError((Object _) {});
    return result;
  }

  Future<void> _waitSlot(CancelToken? token) async {
    while (true) {
      if (token?.isCancelled == true) throw token!.cancelError!;
      final now = DateTime.now();
      while (_starts.isNotEmpty &&
          now.difference(_starts.first) >= const Duration(minutes: 1)) {
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
      final spacing = needSpacing
          ? minInterval - now.difference(last)
          : Duration.zero;
      final rpm = atCap
          ? const Duration(minutes: 1) - now.difference(_starts.first)
          : Duration.zero;
      final wait = spacing > rpm ? spacing : rpm;
      await Future.any<void>([
        Future<void>.delayed(wait),
        if (token != null) token.whenCancel.then<void>((error) => throw error),
      ]);
    }
  }
}

class _PendingRequest {
  _PendingRequest(this.priority, this.run);
  final RequestPriority priority;
  final Future<void> Function() run;
}
