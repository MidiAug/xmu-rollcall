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
  Widget build(BuildContext context) => AppIconButton(
    tooltip: tooltip,
    padding: EdgeInsets.zero,
    extent: 44,
    alignment: alignWithTitle ? Alignment.topCenter : Alignment.center,
    onPressed: enabled ? onPressed ?? () => Navigator.of(context).pop() : null,
    icon: Padding(
      padding: EdgeInsets.only(top: alignWithTitle ? 2 : 0),
      child: const Icon(AppIcons.closeStrong, size: 24),
    ),
  );
}

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
    final strong = background == p.primary;
    final hover = strong ? Color.lerp(p.primary, p.ink, .12)! : p.controlHover;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: AppMobileUi.useTouchChrome(context) ? AppMobileUi.target : 0,
      ),
      child: AppHoverSurface(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        outlined: border,
        backgroundColor: background ?? p.surfaceHigh,
        hoverColor: hover,
        pressedColor: strong
            ? Color.lerp(p.primary, p.ink, .2)!
            : p.controlPressed,
        padding: padding,
        child: AnimatedOpacity(
          duration: AppMotion.instant,
          curve: AppMotion.instantCurve,
          opacity: enabled ? 1 : 0.72,
          child: child,
        ),
      ),
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
    this.hoverColor,
    this.pressedColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool outlined;
  final Color? backgroundColor;
  final Color? hoverColor, pressedColor;

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
    final hover = widget.hoverColor ?? p.cardHover;
    final focus = background == p.primary
        ? Theme.of(context).colorScheme.onPrimary
        : p.focus;
    // Transparent black introduces a gray dip while RGB and alpha interpolate.
    // Match the hover hue at zero alpha to preserve the underlying glass.
    final idle = background.a == 0 ? AppPalette.clearOf(hover) : background;
    final body = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.fast,
      curve: AppMotion.fastCurve,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: _pressed
            ? widget.pressedColor ?? p.content
            : (lift ? hover : idle),
        borderRadius: radius,
        // Keep one border's space in every state so keyboard focus never jumps.
        border: Border.all(
          color: _focused
              ? focus
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
