import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'app_tooltip_anchor.dart';

/// A transient action, separate from persistent navigation selection. Styling
/// comes from AppTheme; this owns hit size, symbol size and the tooltip anchor.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.focusNode,
    this.extent = 44,
    this.framed = false,
    this.active = false,
    this.visualDensity,
    this.alignment = Alignment.center,
    this.padding,
  });
  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final double extent;
  final bool framed;
  final bool active;
  final VisualDensity? visualDensity;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppTooltipAnchor(
      child: IconButton(
        tooltip: tooltip,
        focusNode: focusNode,
        visualDensity: visualDensity,
        onPressed: onPressed,
        alignment: alignment,
        icon: icon,
        style:
            IconButton.styleFrom(
              fixedSize: Size.square(extent),
              minimumSize: Size.square(extent),
              maximumSize: Size.square(extent),
              padding: padding ?? EdgeInsets.all(extent < 40 ? 6 : 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (active) return p.selected;
                if (states.contains(WidgetState.pressed)) {
                  return p.controlPressed;
                }
                if (states.contains(WidgetState.hovered)) {
                  return p.controlHover;
                }
                if (framed) return p.surface;
                return null;
              }),
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.focused)
                      ? p.focus
                      : framed
                      ? p.border
                      : AppPalette.clearOf(p.focus),
                ),
              ),
            ),
      ),
    );
  }
}
