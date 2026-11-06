part of 'chrome.dart';

/// One option in the shared, single-selection segmented control.
class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Compact icon + label choices on one neutral track. Supports touch, keyboard
/// traversal and radio-group semantics without changing the surrounding layout.
class AppSegmentedControl<T> extends StatefulWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.expanded = false,
    this.compact = false,
  });

  final List<AppSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expanded;

  /// Embedded desktop choices use a 32px target without the raised 44px track.
  /// Touch targets retain the app's 48px minimum regardless of this preference.
  final bool compact;

  @override
  State<AppSegmentedControl<T>> createState() => _AppSegmentedControlState<T>();
}

class _AppSegmentedControlState<T> extends State<AppSegmentedControl<T>> {
  final _nodes = <FocusNode>[];

  void _syncNodes() {
    while (_nodes.length < widget.segments.length) {
      _nodes.add(FocusNode());
    }
    while (_nodes.length > widget.segments.length) {
      _nodes.removeLast().dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncNodes();
  }

  @override
  void didUpdateWidget(covariant AppSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNodes();
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.segments.isEmpty) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final focused = _nodes.indexWhere((node) => node.hasFocus);
    if (focused < 0) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final int next;
    if (key == LogicalKeyboardKey.arrowRight) {
      next = (focused + (rtl ? -1 : 1)) % _nodes.length;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      next = (focused + (rtl ? 1 : -1)) % _nodes.length;
    } else if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = _nodes.length - 1;
    } else {
      return KeyEventResult.ignored;
    }
    _nodes[next].requestFocus();
    _select(next);
    return KeyEventResult.handled;
  }

  void _select(int index) {
    final next = widget.segments[index].value;
    if (next != widget.value) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final style = Theme.of(context).textTheme.labelLarge!.copyWith(
      fontWeight: widget.compact ? FontWeight.w600 : null,
    );
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    var segmentWidth = 0.0;
    for (final segment in widget.segments) {
      painter.text = TextSpan(text: segment.label, style: style);
      painter.layout();
      final width = painter.width + (segment.icon == null ? 0 : 24) + 20;
      if (width > segmentWidth) segmentWidth = width;
    }
    painter.dispose();
    final touch = AppMobileUi.useTouchChrome(context);
    if (touch) {
      segmentWidth =
          (segmentWidth - (widget.segments.any((s) => s.icon != null) ? 24 : 0))
              .clamp(48.0, double.infinity);
    }
    final selected = widget.segments.indexWhere((s) => s.value == widget.value);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final x = widget.segments.length < 2
        ? 0.0
        : (selected.clamp(0, widget.segments.length - 1) /
                      (widget.segments.length - 1) *
                      2 -
                  1) *
              (rtl ? -1 : 1);
    if (widget.expanded && widget.segments.isNotEmpty) {
      return LayoutBuilder(
        builder: (context, bounds) {
          if (bounds.maxWidth.isFinite &&
              bounds.maxWidth < segmentWidth * widget.segments.length + 6) {
            // Keep the complete range names at large text sizes. Balance the
            // rows while retaining one focus group and its original key order.
            final available = (bounds.maxWidth - 6).clamp(0.0, double.infinity);
            final maxColumns = ((available + 4) / (segmentWidth + 4))
                .floor()
                .clamp(1, widget.segments.length);
            final rows = (widget.segments.length / maxColumns).ceil();
            final columns = (widget.segments.length / rows).ceil();
            final width = (available - (columns - 1) * 4) / columns;
            return Focus(
              canRequestFocus: false,
              includeSemantics: false,
              onKeyEvent: _handleKey,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: p.content,
                  borderRadius: BorderRadius.circular(AppRadii.input),
                ),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < widget.segments.length; i++)
                      SizedBox(
                        width: width,
                        child: DecoratedBox(
                          key: i == selected
                              ? const ValueKey('segment-selection')
                              : null,
                          decoration: BoxDecoration(
                            color: i == selected ? p.surface : null,
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                          ),
                          child: _segment(i),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }
          return _track(context, p, touch, selected, x, segmentWidth);
        },
      );
    }
    return _track(context, p, touch, selected, x, segmentWidth);
  }

  Widget _track(
    BuildContext context,
    AppPalette p,
    bool touch,
    int selected,
    double x,
    double segmentWidth,
  ) {
    if (touch) {
      return Focus(
        canRequestFocus: false,
        includeSemantics: false,
        onKeyEvent: _handleKey,
        child: SizedBox(
          height: widget.compact ? null : AppMobileUi.target,
          child: Stack(
            children: [
              if (selected >= 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 2,
                  child: AnimatedAlign(
                    alignment: Alignment(x, 0),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : AppMotion.fast,
                    child: FractionallySizedBox(
                      widthFactor: 1 / widget.segments.length,
                      heightFactor: 1,
                      child: ColoredBox(
                        key: const ValueKey('segment-selection'),
                        color: p.primary,
                      ),
                    ),
                  ),
                ),
              Row(
                mainAxisSize: widget.expanded
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.segments.length; i++)
                    if (widget.expanded)
                      Expanded(child: _segment(i))
                    else
                      SizedBox(width: segmentWidth, child: _segment(i)),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Focus(
      canRequestFocus: false,
      includeSemantics: false,
      onKeyEvent: _handleKey,
      child: Container(
        padding: widget.compact
            ? const EdgeInsets.symmetric(horizontal: 2)
            : const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: p.content,
          border: widget.compact ? null : Border.all(color: p.borderStrong),
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
        foregroundDecoration: widget.compact
            ? BoxDecoration(
                border: Border.all(
                  color: MediaQuery.highContrastOf(context)
                      ? p.muted
                      : p.border,
                ),
                borderRadius: BorderRadius.circular(AppRadii.input),
              )
            : null,
        child: Stack(
          children: [
            if (selected >= 0)
              Positioned.fill(
                child: AnimatedAlign(
                  key: const ValueKey('segment-selection'),
                  alignment: Alignment(x, 0),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : AppMotion.fast,
                  curve: AppMotion.fastCurve,
                  child: FractionallySizedBox(
                    widthFactor: 1 / widget.segments.length,
                    heightFactor: 1,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: widget.compact ? 2 : 0,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(
                            widget.compact
                                ? AppRadii.control - 2
                                : AppRadii.control,
                          ),
                          border:
                              widget.compact &&
                                  MediaQuery.highContrastOf(context)
                              ? Border.all(color: p.primary)
                              : null,
                          boxShadow: widget.compact
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: p.isDark ? .18 : .07,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisSize: widget.expanded
                  ? MainAxisSize.max
                  : MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.segments.length; i++)
                  if (widget.expanded)
                    Expanded(child: _segment(i))
                  else
                    SizedBox(width: segmentWidth, child: _segment(i)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(int index) {
    final s = widget.segments[index];
    return _SegmentButton(
      key: ValueKey(s.value),
      label: s.label,
      icon: s.icon,
      selected: s.value == widget.value,
      focusNode: _nodes[index],
      onTap: () => _select(index),
      compact: widget.compact,
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.focusNode,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final foreground = selected ? p.primary : p.muted;
    if (AppMobileUi.useTouchChrome(context)) {
      return Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: TextButton(
          focusNode: focusNode,
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(AppMobileUi.target, AppMobileUi.target),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            foregroundColor: foreground,
            shape: const RoundedRectangleBorder(),
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return _AppSurfaceInteraction(
      onTap: onTap,
      focusNode: focusNode,
      builder: (context, states) {
        final active =
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed);
        final focused = states.contains(WidgetState.focused);
        final radius = BorderRadius.circular(
          compact ? AppRadii.control - 2 : AppRadii.control,
        );
        return Semantics(
          button: true,
          selected: selected,
          inMutuallyExclusiveGroup: true,
          child: ClipRRect(
            borderRadius: radius,
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppMotion.instant,
              curve: AppMotion.instantCurve,
              constraints: BoxConstraints(
                minHeight: AppMobileUi.useTouchChrome(context)
                    ? AppMobileUi.target
                    : compact
                    ? 32
                    : 36,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: active ? .04 : 0),
                borderRadius: radius,
                border: Border.all(
                  color: focused ? p.primary : AppPalette.clearOf(p.primary),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: compact && selected
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
