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
    hoverOutline: false,
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
    final hover = strong ? p.primaryHover : p.controlHover;
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
        pressedColor: strong ? p.primaryPressed : p.controlPressed,
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
class AppHoverSurface extends StatelessWidget {
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
  Widget build(BuildContext context) => _AppSurfaceInteraction(
    onTap: onTap,
    builder: (context, states) => _buildSurface(context, states),
  );

  Widget _buildSurface(BuildContext context, Set<WidgetState> states) {
    final pressed = states.contains(WidgetState.pressed);
    final hovered = states.contains(WidgetState.hovered);
    final focused = states.contains(WidgetState.focused);
    final p = AppPalette.of(context);
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.card);
    final lift = onTap != null && (pressed || hovered || focused);
    final background = backgroundColor ?? p.surface;
    final strong = background == p.primary;
    final hover = hoverColor ?? (strong ? p.primaryHover : p.cardHover);
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
      padding: padding,
      decoration: BoxDecoration(
        color: pressed
            ? pressedColor ?? (strong ? p.primaryPressed : p.content)
            : (lift ? hover : idle),
        borderRadius: radius,
        // Keep one border's space in every state so keyboard focus never jumps.
        border: Border.all(
          color: focused
              ? focus
              : outlined
              ? (lift ? p.borderStrong : p.border)
              : AppPalette.clearOf(p.focus),
        ),
      ),
      child: child,
    );

    return ClipRRect(borderRadius: radius, child: body);
  }
}

/// Owns input only. Each surface decides how its states should be painted.
/// No Material ink can leak through a caller's custom surface.
class _AppSurfaceInteraction extends StatefulWidget {
  const _AppSurfaceInteraction({
    required this.onTap,
    required this.builder,
    this.focusNode,
    this.autofocus = false,
    this.pointerAutofocus = false,
  });
  final VoidCallback? onTap;
  final Widget Function(BuildContext, Set<WidgetState>) builder;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool pointerAutofocus;

  @override
  State<_AppSurfaceInteraction> createState() => _AppSurfaceInteractionState();
}

class _AppSurfaceInteractionState extends State<_AppSurfaceInteraction> {
  bool _hover = false, _pressed = false, _focus = false;
  late bool _pointerFocus = widget.autofocus && widget.pointerAutofocus;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    // Passive settings rows must leave their embedded controls' focus and
    // semantics untouched rather than introduce an inactive action ancestor.
    if (!enabled) return widget.builder(context, const <WidgetState>{});
    final body = widget.builder(context, {
      if (enabled && _hover) WidgetState.hovered,
      if (enabled && _pressed) WidgetState.pressed,
      if (enabled && _focus && !_pointerFocus) WidgetState.focused,
    });
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        canRequestFocus: false,
        includeSemantics: false,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent && _pointerFocus) {
            setState(() => _pointerFocus = false);
          }
          return KeyEventResult.ignored;
        },
        child: Listener(
          onPointerDown: (_) {
            // Desktop traditional highlight mode includes mouse input. Keep
            // actual focus for navigation, but draw its ring only for keys.
            setState(() => _pointerFocus = true);
            (widget.focusNode ?? _focusNode).requestFocus();
          },
          child: FocusableActionDetector(
            enabled: enabled,
            focusNode: widget.focusNode ?? _focusNode,
            autofocus: widget.autofocus,
            mouseCursor: WidgetStateMouseCursor.adaptiveClickable,
            onFocusChange: (focused) {
              if (!focused && _pointerFocus) {
                setState(() => _pointerFocus = false);
              }
            },
            onShowFocusHighlight: (value) => setState(() => _focus = value),
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  if (_pointerFocus) setState(() => _pointerFocus = false);
                  widget.onTap?.call();
                  return null;
                },
              ),
            },
            child: Semantics(
              button: enabled ? true : null,
              onTap: widget.onTap,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: widget.onTap,
                onTapDown: enabled
                    ? (_) => setState(() => _pressed = true)
                    : null,
                onTapUp: enabled
                    ? (_) => setState(() => _pressed = false)
                    : null,
                onTapCancel: enabled
                    ? () => setState(() => _pressed = false)
                    : null,
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
