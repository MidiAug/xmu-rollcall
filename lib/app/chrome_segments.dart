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
  });

  final List<AppSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expanded;

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
    final style = Theme.of(context).textTheme.labelLarge!;
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
    final selected = widget.segments.indexWhere((s) => s.value == widget.value);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final x = widget.segments.length < 2
        ? 0.0
        : (selected.clamp(0, widget.segments.length - 1) /
                      (widget.segments.length - 1) *
                      2 -
                  1) *
              (rtl ? -1 : 1);
    return Focus(
      canRequestFocus: false,
      includeSemantics: false,
      onKeyEvent: _handleKey,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: p.content,
          border: Border.all(color: p.borderStrong),
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
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
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(p.selected, p.content),
                        borderRadius: BorderRadius.circular(AppRadii.control),
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
    );
  }
}

class _SegmentButton extends StatefulWidget {
  const _SegmentButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.focusNode,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  State<_SegmentButton> createState() => _SegmentButtonState();
}

class _SegmentButtonState extends State<_SegmentButton> {
  var _focused = false;
  var _hovered = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final foreground = widget.selected ? p.primary : p.muted;
    final active = _hovered || _pressed;
    final radius = BorderRadius.circular(AppRadii.control);
    return Semantics(
      button: true,
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          focusNode: widget.focusNode,
          borderRadius: radius,
          onFocusChange: (v) => setState(() => _focused = v),
          onHover: (v) => setState(() => _hovered = v),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          onTap: widget.onTap,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppMotion.instant,
            curve: AppMotion.instantCurve,
            constraints: BoxConstraints(
              minHeight: AppDensity.isTouch(context) ? 44 : 36,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: AppDensity.isTouch(context) ? 8 : 4,
            ),
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: active ? .04 : 0),
              borderRadius: radius,
              border: Border.all(
                color: _focused ? p.primary : AppPalette.clearOf(p.primary),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18, color: foreground),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
