part of 'chrome.dart';

/// Shared visual language for choice menus and contextual action menus.
abstract final class AppMenuStyle {
  static const inset = 6.0;
  static const elevation = 8.0;
  static ShapeBorder shape(BuildContext context) => RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.card),
    side: BorderSide(color: AppPalette.of(context).border),
  );
  static Color shadow(BuildContext context) => Colors.black.withValues(
    alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.10,
  );
}

/// Compact, bounded select trigger. Focus, hover and open states stay in-shape.
class AppSelectTrigger extends StatelessWidget {
  const AppSelectTrigger({
    super.key,
    required this.label,
    required this.onTap,
    this.open = false,
    this.leading,
    this.trailing,
    this.focusNode,
    this.compact = false,
    this.subtitle,
    this.plain = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool open;
  final Widget? leading;
  final Widget? trailing;
  final FocusNode? focusNode;
  final bool compact;

  final String? subtitle;
  final bool plain;

  @override
  Widget build(BuildContext context) => _AppSurfaceInteraction(
    onTap: onTap,
    focusNode: focusNode,
    builder: (context, states) {
      final p = AppPalette.of(context);
      final enabled = onTap != null;
      final hovering = states.contains(WidgetState.hovered);
      final pressed = states.contains(WidgetState.pressed);
      final outlined =
          enabled && (open || states.contains(WidgetState.focused));
      return Semantics(
        button: true,
        enabled: enabled,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppMotion.fast,
            constraints: BoxConstraints(
              minHeight: compact
                  ? AppDensity.controlHeight(context)
                  : AppMobileUi.useTouchChrome(context)
                  ? AppMobileUi.target
                  : 36,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: pressed && enabled
                  ? p.controlPressed
                  : hovering
                  ? p.controlHover
                  : plain
                  ? AppPalette.clearOf(p.controlHover)
                  : AppMobileUi.useTouchChrome(context)
                  ? p.controlSurface
                  : p.surface,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(
                color: outlined
                    ? p.focus
                    : hovering
                    ? p.controlOutlineHover
                    : plain
                    ? AppPalette.clearOf(p.primary)
                    : AppMobileUi.useTouchChrome(context)
                    ? p.mobileOutline
                    : p.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTruncatedText(
                        label,
                        style: TextStyle(
                          fontSize: compact ? 13 : 14,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: enabled ? p.ink : p.muted,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(fontSize: 11, color: p.muted),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 6), trailing!],
                SizedBox(width: compact ? 4 : 8),
                AnimatedRotation(
                  turns: open ? .5 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : AppMotion.fast,
                  child: Icon(AppIcons.down, size: 12, color: p.muted),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
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
