import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'chrome.dart';

/// A transient action, separate from persistent navigation selection. Styling
/// comes from AppTheme; this owns hit size, symbol size and the tooltip anchor.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.focusNode,
    this.extent,
    this.active = false,
    this.visualDensity,
    this.alignment = Alignment.center,
    this.padding,
  });
  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final double? extent;
  final bool active;
  final VisualDensity? visualDensity;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final resolvedExtent = extent ?? (AppMobileUi.useTouchChrome(context) ? 44.0 : 34.0);
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
              fixedSize: Size.square(resolvedExtent),
              minimumSize: Size.square(resolvedExtent),
              maximumSize: Size.square(resolvedExtent),
              padding: padding ?? EdgeInsets.all(resolvedExtent < 40 ? 6 : 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ).copyWith(
              shape: resolvedExtent < 40
                  ? WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    )
                  : null,
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return active ? p.controlHover : null;
                }
                if (active) {
                  // An open menu stays distinctly active while neutral pointer
                  // feedback layers over it.
                  final overlayBase = p.isDark ? Colors.white : p.ink;
                  return Color.alphaBlend(
                    overlayBase.withValues(
                      alpha: states.contains(WidgetState.pressed)
                          ? .08
                          : states.contains(WidgetState.hovered)
                          ? .04
                          : 0,
                    ),
                    p.controlPressed,
                  );
                }
                if (states.contains(WidgetState.pressed)) {
                  return p.controlPressed;
                }
                if (states.contains(WidgetState.hovered)) {
                  return p.controlHover;
                }
                return null;
              }),
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.focused)
                      ? p.focus
                      : AppPalette.clearOf(p.focus),
                ),
              ),
            ),
      ),
    );
  }
}
