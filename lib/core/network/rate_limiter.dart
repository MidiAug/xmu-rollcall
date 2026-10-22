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
    this.foregroundReserve = 5,
    this.window = const Duration(minutes: 1),
  }) : assert(maxPerMinute > 0),
       assert(maxConcurrent > 0),
       assert(foregroundReserve >= 0),
       assert(window > Duration.zero);
  final int maxPerMinute;
  final Duration minInterval;
  final int maxConcurrent;
  final int foregroundReserve;
  final Duration window;
  final Queue<DateTime> _starts = Queue<DateTime>();
  final List<_PendingRequest> _pending = [];
  DateTime? _lastStart;
  int _active = 0;
  int _activeBackground = 0;
  int get _backgroundConcurrency => maxConcurrent > 1 ? maxConcurrent - 1 : 1;
  int get _backgroundBudget =>
      maxPerMinute - foregroundReserve.clamp(0, maxPerMinute - 1);

  Future<T> schedule<T>(
    Future<T> Function() action, {
    RequestPriority priority = RequestPriority.normal,
    CancelToken? cancelToken,
  }) {
    final result = Completer<T>();
    final request = _PendingRequest(priority, () async {
      try {
        await waitForStart(cancelToken: cancelToken, priority: priority);
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
      int? index;
      for (var i = 0; i < _pending.length; i++) {
        if (_pending[i].priority == RequestPriority.background &&
            _activeBackground >= _backgroundConcurrency) {
          continue;
        }
        if (index == null ||
            _pending[i].priority.index > _pending[index].priority.index) {
          index = i;
        }
      }
      if (index == null) return;
      final request = _pending.removeAt(index);
      final background = request.priority == RequestPriority.background;
      _active++;
      if (background) _activeBackground++;
      unawaited(
        request.run().whenComplete(() {
          _active--;
          if (background) _activeBackground--;
          _drain();
        }),
      );
    }
  }

  /// Admission checks are synchronous until the sleep, so no lock is held while
  /// a background request waits for its budget. Foreground work can use the
  /// reserved starts without increasing the global per-window cap.
  Future<void> waitForStart({
    CancelToken? cancelToken,
    RequestPriority priority = RequestPriority.normal,
  }) => _waitSlot(cancelToken, priority);

  Future<void> _waitSlot(CancelToken? token, RequestPriority priority) async {
    while (true) {
      if (token?.isCancelled == true) throw token!.cancelError!;
      final now = DateTime.now();
      while (_starts.isNotEmpty && now.difference(_starts.first) >= window) {
        _starts.removeFirst();
      }
      final last = _lastStart;
      final needSpacing = last != null && now.difference(last) < minInterval;
      final cap = priority == RequestPriority.background
          ? _backgroundBudget
          : maxPerMinute;
      final atCap = _starts.length >= cap;
      if (!needSpacing && !atCap) {
        _lastStart = now;
        _starts.addLast(now);
        return;
      }
      final spacing = needSpacing
          ? minInterval - now.difference(last)
          : Duration.zero;
      final rpm = atCap
          ? window - now.difference(_starts.first)
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
