part of 'chrome.dart';

/// Secondary touch actions share the same surface, outline and hit target.
abstract final class AppControlStyle {
  static ButtonStyle touchIcon(BuildContext context) {
    final p = AppPalette.of(context);
    return IconButton.styleFrom(
      minimumSize: const Size(AppMobileUi.target, AppMobileUi.target),
      visualDensity: VisualDensity.standard,
      backgroundColor: p.controlSurface,
      foregroundColor: p.primary,
      side: BorderSide(color: p.mobileOutline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(10),
    );
  }
}

/// A compact table-cell action on the table's existing Material surface.
/// Avoids creating a separate button surface and minimum-width layout per row.
class AppTableAction extends StatelessWidget {
  const AppTableAction({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });
  final String label, tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppTooltipAnchor(
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          enabled: onPressed != null,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadii.control),
            hoverColor: p.hover,
            focusColor: p.selected,
            highlightColor: p.selected,
            splashFactory: NoSplash.splashFactory,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: onPressed == null
                        ? p.muted.withValues(alpha: .5)
                        : p.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Strong, consistently aligned dismissal action with a full touch target.
class AppSheetCloseButton extends StatelessWidget {
  const AppSheetCloseButton({
    super.key,
    this.tooltip = '关闭',
    this.alignWithTitle = false,
    this.onPressed,
    this.enabled = true,
  });
  final String tooltip;
  final bool alignWithTitle;
  final VoidCallback? onPressed;
  final bool enabled;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    padding: EdgeInsets.zero,
    constraints: BoxConstraints(
      minWidth: AppMobileUi.useTouchChrome(context) ? AppMobileUi.target : 44,
      minHeight: AppMobileUi.useTouchChrome(context) ? AppMobileUi.target : 44,
    ),
    alignment: alignWithTitle ? Alignment.topCenter : Alignment.center,
    color: AppPalette.of(context).ink,
    onPressed: enabled ? onPressed ?? () => Navigator.of(context).pop() : null,
    icon: Padding(
      padding: EdgeInsets.only(top: alignWithTitle ? 2 : 0),
      child: const Icon(AppIcons.closeStrong, size: 24),
    ),
  );
}

/// Soft pill strip for grouped icon actions (desktop toolbars).
/// Soft stadium control without Material ripple (poll / quick actions).
class AppQuietPill extends StatelessWidget {
  const AppQuietPill({
    super.key,
    required this.child,
    this.onTap,
    this.background,
    this.border = true,
    this.radius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? background;
  final bool border;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final enabled = onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          hoverColor: p.hover,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          focusColor: p.hover,
          onTap: onTap,
          child: AnimatedOpacity(
            duration: AppMotion.instant,
            curve: AppMotion.instantCurve,
            opacity: enabled ? 1 : 0.72,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: AppMobileUi.useTouchChrome(context)
                    ? AppMobileUi.target
                    : 0,
              ),
              child: Ink(
                padding: padding,
                decoration: BoxDecoration(
                  color: background ?? p.surfaceHigh,
                  borderRadius: BorderRadius.circular(radius),
                  border: border ? Border.all(color: p.border) : null,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppIconCluster extends StatelessWidget {
  const AppIconCluster({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: p.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Shared tile interaction with a stable focus outline and surface feedback.
class AppHoverSurface extends StatefulWidget {
  const AppHoverSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.outlined = true,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool outlined;
  final Color? backgroundColor;

  @override
  State<AppHoverSurface> createState() => _AppHoverSurfaceState();
}

class _AppHoverSurfaceState extends State<AppHoverSurface> {
  var _hover = false;
  var _pressed = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(AppRadii.card);
    final lift = widget.onTap != null && (_pressed || _hover || _focused);
    final background = widget.backgroundColor ?? p.surface;
    // Transparent black introduces a gray dip while RGB and alpha interpolate.
    // Match the hover hue at zero alpha to preserve the underlying glass.
    final idle = background.a == 0
        ? AppPalette.clearOf(p.cardHover)
        : background;
    final body = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.fastCurve,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: _pressed ? p.content : (lift ? p.cardHover : idle),
        borderRadius: radius,
        // Keep one border's space in every state so keyboard focus never jumps.
        border: Border.all(
          color: _focused
              ? p.focus
              : widget.outlined
              ? (lift ? p.borderStrong : p.border)
              : AppPalette.clearOf(p.focus),
        ),
      ),
      child: widget.child,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: widget.onTap == null
          ? body
          : Material(
              type: MaterialType.transparency,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: radius,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                focusColor: Colors.transparent,
                onFocusChange: (focused) => setState(() => _focused = focused),
                onHighlightChanged: (pressed) =>
                    setState(() => _pressed = pressed),
                onTap: widget.onTap,
                child: body,
              ),
            ),
    );
  }
}
