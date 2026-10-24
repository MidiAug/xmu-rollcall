part of 'chrome.dart';

/// Soft pill strip for grouped icon actions (desktop toolbars).
/// Soft stadium control without Material ripple (poll / quick actions).
class AppQuietPill extends StatelessWidget {
  const AppQuietPill({
    super.key,
    required this.child,
    this.onTap,
    this.background,
    this.border = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? background;
  final bool border;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final enabled = onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          hoverColor: p.hover,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          focusColor: p.hover,
          onTap: onTap,
          child: AnimatedOpacity(
            duration: AppMotion.instant,
            curve: AppMotion.instantCurve,
            opacity: enabled ? 1 : 0.72,
            child: Ink(
              padding: padding,
              decoration: BoxDecoration(
                color: background ?? p.surfaceHigh,
                borderRadius: BorderRadius.circular(18),
                border: border ? Border.all(color: p.border) : null,
              ),
              child: child,
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

/// List / tile surface: color lift + hairline **on hover only** (Quiet Utility).
class AppHoverSurface extends StatefulWidget {
  const AppHoverSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.outlined = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool outlined;

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
    final body = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.fastCurve,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: lift ? p.cardHover : p.surface,
        borderRadius: radius,
        border: widget.outlined
            ? Border.all(color: lift ? p.borderStrong : p.border)
            : null,
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
