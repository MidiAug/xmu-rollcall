part of 'chrome.dart';

/// Shared visual language for choice menus and contextual action menus.
abstract final class AppMenuStyle {
  static const inset = 6.0;
  static const elevation = 6.0;
  static ShapeBorder shape(BuildContext context) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.card),
    side: BorderSide(color: AppPalette.of(context).borderStrong),
  );
  static Color shadow(BuildContext context) => Colors.black.withValues(
    alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.10,
  );
}

/// Compact, bounded select trigger. Focus, hover and open states stay in-shape.
class AppSelectTrigger extends StatefulWidget {
  const AppSelectTrigger({
    super.key,
    required this.label,
    required this.onTap,
    this.open = false,
    this.leading,
    this.focusNode,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool open;
  final Widget? leading;
  final FocusNode? focusNode;
  final bool compact;

  @override
  State<AppSelectTrigger> createState() => _AppSelectTriggerState();
}

class _AppSelectTriggerState extends State<AppSelectTrigger> {
  bool _hover = false;
  bool _focused = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final enabled = widget.onTap != null;
    final active = enabled && (widget.open || _focused || _pressed);
    return Semantics(
      button: true,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: InkWell(
            focusNode: widget.focusNode,
            onTap: widget.onTap,
            onFocusChange: (value) => setState(() => _focused = value),
            onHighlightChanged: (value) => setState(() => _pressed = value),
            splashFactory: NoSplash.splashFactory,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              constraints: BoxConstraints(
                minHeight: AppDensity.isTouch(context) ? 44 : 36,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 8 : 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: active
                    ? p.selected
                    : _hover && enabled
                    ? p.hover
                    : p.content,
                borderRadius: BorderRadius.circular(AppRadii.control),
                border: Border.all(
                  color: active
                      ? p.primary.withValues(alpha: 0.4)
                      : p.borderStrong,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: AppTruncatedText(
                      widget.label,
                      style: TextStyle(
                        fontSize: widget.compact ? 13 : 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: enabled ? p.ink : p.muted,
                      ),
                    ),
                  ),
                  SizedBox(width: widget.compact ? 4 : 8),
                  AnimatedRotation(
                    turns: widget.open ? 0.5 : 0,
                    duration: AppMotion.fast,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: active ? p.primary : p.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Popup routes use the same inset option without a second full-width hover layer.
class AppPopupMenuItem<T> extends PopupMenuItem<T> {
  const AppPopupMenuItem({
    super.key,
    required T value,
    required this.label,
    this.selected = false,
    this.showCheck = false,
    this.icon,
    this.danger = false,
    this.rowWidth = 180,
  }) : super(value: value, height: 44, child: const SizedBox.shrink());
  final String label;
  final bool selected;
  final bool showCheck;
  final IconData? icon;
  final bool danger;
  final double rowWidth;
  @override
  PopupMenuItemState<T, AppPopupMenuItem<T>> createState() =>
      _AppPopupMenuItemState<T>();
}

class _AppPopupMenuItemState<T>
    extends PopupMenuItemState<T, AppPopupMenuItem<T>> {
  @override
  Widget build(BuildContext context) => buildSemantics(
    child: SizedBox(
      width: widget.rowWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppMenuStyle.inset,
          vertical: 2,
        ),
        child: AppMenuOption(
          label: widget.label,
          selected: widget.selected,
          showCheck: widget.showCheck,
          leadingIcon: widget.icon,
          danger: widget.danger,
          onTap: handleTap,
        ),
      ),
    ),
  );
}
