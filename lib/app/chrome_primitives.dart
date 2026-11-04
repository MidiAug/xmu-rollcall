part of 'chrome.dart';

/// Frosted chrome is clipped to its own bounds. Static content surfaces use
/// blur=0 so scrolling data never pays for a backdrop filter per row.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.blur = 18,
    this.opacity = .78,
  });
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final double blur, opacity;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = borderRadius ?? BorderRadius.circular(AppRadii.island);
    final highContrast = MediaQuery.highContrastOf(context);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            p.surface.withValues(alpha: highContrast || opacity == 1 ? 1 : .97),
            p.surface.withValues(alpha: highContrast ? 1 : opacity),
          ],
        ),
        border: Border.all(
          color: p.isDark
              ? Colors.white.withValues(alpha: .12)
              : p.border.withValues(alpha: .8),
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? .18 : .035),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? .08 : .015),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: blur > 0 && !highContrast
            ? BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: surface,
              )
            : surface,
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      alignment: Alignment.center,
      child: UserCheckIcon(size: size * 0.58, color: p.primary),
    );
  }
}

/// Isolates a tooltip / icon-button anchor for Windows accessibility.
///
/// Adjacent [Tooltip] overlays can drop their traversal-parent id when
/// semantics configs merge; the Windows embedder then rejects the whole
/// AXTree update (`Nodes left pending…`, flutter/flutter#182444). Each
/// tooltip anchor needs its own semantics container on desktop.
class AppTooltipAnchor extends StatelessWidget {
  const AppTooltipAnchor({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!PlatformHooks.isDesktop) return child;
    return Semantics(container: true, child: child);
  }
}

/// Header refresh control — spins while [onRefresh] runs; list stays put.
class AppRefreshButton extends StatefulWidget {
  const AppRefreshButton({
    super.key,
    required this.onRefresh,
    this.color,
    this.iconSize,
    this.tooltip = '刷新',
    this.visualDensity,
    this.extent,
    this.busy = false,
  });

  final Future<void> Function() onRefresh;
  final Color? color;
  final double? iconSize;
  final String tooltip;
  final VisualDensity? visualDensity;
  final double? extent;

  /// Shared request state, including requests started by another control.
  final bool busy;

  @override
  State<AppRefreshButton> createState() => _AppRefreshButtonState();
}

class _AppRefreshButtonState extends State<AppRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.busy) _spin.repeat();
  }

  @override
  void didUpdateWidget(AppRefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy == widget.busy) return;
    if (_busy || widget.busy) {
      _spin.repeat();
    } else {
      _spin
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _handle() async {
    if (_busy || widget.busy) return;
    setState(() => _busy = true);
    _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (!widget.busy) {
          _spin
            ..stop()
            ..value = 0;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppTooltipAnchor(
      child: IconButton(
        tooltip: widget.tooltip,
        style: PlatformHooks.isDesktop && !AppMobileUi.useTouchChrome(context)
            ? IconButton.styleFrom(
                minimumSize: Size.square(widget.extent ?? 34),
                backgroundColor: p.surface,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.all(6),
                side: BorderSide(color: p.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
              )
            : AppMobileUi.useTouchChrome(context)
            ? IconButton.styleFrom(
                minimumSize: const Size(AppMobileUi.target, AppMobileUi.target),
                visualDensity: VisualDensity.standard,
                backgroundColor: Colors.transparent,
                side: BorderSide.none,
                hoverColor: Colors.transparent,
              )
            : null,
        visualDensity: widget.visualDensity,
        onPressed: _busy || widget.busy ? null : _handle,
        icon: RotationTransition(
          turns: _spin,
          child: Icon(
            AppIcons.refresh,
            color: widget.color ?? p.muted,
            size: widget.iconSize,
          ),
        ),
      ),
    );
  }
}

class AppTextLink extends StatelessWidget {
  const AppTextLink(this.label, {super.key, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppPalette.of(context).muted,
          ),
        ),
        const SizedBox(width: 4),
        Icon(AppIcons.right, size: 14, color: AppPalette.of(context).muted),
      ],
    ),
  );
}
