import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Material swipe-to-refresh with cancel-by-reversing.
///
/// Matches Material / Android [SwipeRefreshLayout] / Compose `PullToRefresh`
/// semantics ([MD swipe-to-refresh](https://m1.material.io/patterns/swipe-to-refresh.html)):
///
/// - Indicator tracks the finger for the whole drag (including reverse).
/// - Refresh runs only on **release** while still past the threshold.
/// - Reversing past the threshold before release cancels.
///
/// Unlike Flutter's [RefreshIndicator], pull distance is driven by pointer
/// deltas (not overscroll alone), so empty / short lists on Android can still
/// cancel after arming.
class AppPullToRefresh extends StatefulWidget {
  const AppPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
    this.displacement = 40,
    this.edgeOffset = 0,
    this.threshold = 72,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;
  final Color? backgroundColor;

  /// Resting offset of the indicator while refreshing (below [edgeOffset]).
  final double displacement;

  /// Extra top inset (e.g. under a pinned header).
  final double edgeOffset;

  /// Finger travel (after drag rate) needed to arm; release above this refreshes.
  final double threshold;

  final ScrollNotificationPredicate notificationPredicate;

  @override
  State<AppPullToRefresh> createState() => AppPullToRefreshState();
}

@visibleForTesting
enum AppPullToRefreshStatus { idle, dragging, armed, refreshing }

class AppPullToRefreshState extends State<AppPullToRefresh>
    with SingleTickerProviderStateMixin {
  /// Android SwipeRefreshLayout drag rate.
  static const dragRate = 0.5;

  late final AnimationController _anim;
  double _pull = 0;
  bool _refreshing = false;
  int? _pointer;
  double _pointerStartY = 0;
  bool _dragging = false;
  bool _atTop = true;
  double _touchSlop = 18;

  @visibleForTesting
  double get pullDistance => _pull;

  @visibleForTesting
  AppPullToRefreshStatus get status {
    if (_refreshing) return AppPullToRefreshStatus.refreshing;
    if (!_dragging && _pull <= 0) return AppPullToRefreshStatus.idle;
    if (_pull >= widget.threshold) return AppPullToRefreshStatus.armed;
    return AppPullToRefreshStatus.dragging;
  }

  @override
  void initState() {
    super.initState();
    _anim = AnimationController.unbounded(vsync: this)..addListener(() {
      setState(() => _pull = _anim.value);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _touchSlop =
        MediaQuery.maybeGestureSettingsOf(context)?.touchSlop ?? kTouchSlop;
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification)) return false;
    _atTop = notification.metrics.extentBefore <= 0.0 &&
        (notification.metrics.axisDirection == AxisDirection.down ||
            notification.metrics.axisDirection == AxisDirection.up);
    return false;
  }

  bool _onOverscrollIndicator(OverscrollIndicatorNotification notification) {
    if ((_dragging || _refreshing) && notification.leading) {
      notification.disallowIndicator();
      return true;
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent e) {
    if (_refreshing) return;
    _pointer = e.pointer;
    _pointerStartY = e.position.dy;
    _dragging = false;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_refreshing || e.pointer != _pointer) return;

    final raw = e.position.dy - _pointerStartY;

    if (!_dragging) {
      if (raw.abs() < _touchSlop) return;
      // Only claim a downward pull while the scrollable is at the leading edge.
      if (raw > 0 && _atTop) {
        _dragging = true;
        _anim.stop();
      } else {
        _pointer = null;
        return;
      }
    }

    final next = (raw * dragRate).clamp(0.0, widget.threshold * 2.0);
    if (next == _pull) return;
    setState(() => _pull = next);
  }

  void _onPointerUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (!_dragging) return;
    _dragging = false;
    _settle();
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (!_dragging) return;
    _dragging = false;
    _animateTo(0);
  }

  void _settle() {
    if (_pull >= widget.threshold) {
      _startRefresh();
    } else {
      _animateTo(0);
    }
  }

  Future<void> _startRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _animateTo(widget.threshold);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
        await _animateTo(0);
      }
    }
  }

  Future<void> _animateTo(double target) {
    _anim.value = _pull;
    return _anim.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = widget.color ?? p.primary;
    final bg = widget.backgroundColor ?? p.surface;
    final show = _pull > 0.5 || _refreshing;
    final progress = (_pull / widget.threshold).clamp(0.0, 1.0);
    final top = widget.edgeOffset +
        (_refreshing
            ? widget.displacement
            : (widget.displacement * progress));

    return NotificationListener<OverscrollIndicatorNotification>(
      onNotification: _onOverscrollIndicator,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: Stack(
            children: [
              widget.child,
              if (show)
                Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _PullIndicator(
                      refreshing: _refreshing,
                      progress: progress,
                      color: color,
                      background: bg,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PullIndicator extends StatelessWidget {
  const _PullIndicator({
    required this.refreshing,
    required this.progress,
    required this.color,
    required this.background,
  });

  final bool refreshing;
  final double progress;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: background,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: refreshing
              ? CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: color,
                )
              : CircularProgressIndicator(
                  value: progress <= 0 ? null : progress,
                  strokeWidth: 2.5,
                  color: color,
                ),
        ),
      ),
    );
  }
}
