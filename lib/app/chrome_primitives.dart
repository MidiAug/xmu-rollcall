part of 'chrome.dart';

/// Consistent optical frame for symbolic list markers, distinct from the larger
/// illustrated service destinations. No shadow or backdrop filter per row.
class AppIconSurface extends StatelessWidget {
  const AppIconSurface({super.key, required this.child, this.size = 36});
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.content,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: p.border),
      ),
      child: IconTheme(
        data: IconThemeData(color: p.primary, size: 19),
        child: child,
      ),
    );
  }
}

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
    return AppIconButton(
      tooltip: widget.tooltip,
      extent: widget.extent ?? (AppMobileUi.useTouchChrome(context) ? 44 : 34),
      framed: PlatformHooks.isDesktop && !AppMobileUi.useTouchChrome(context),
      visualDensity: widget.visualDensity,
      onPressed: _busy || widget.busy ? null : _handle,
      icon: RotationTransition(
        turns: _spin,
        child: SizedBox.square(
          dimension: widget.iconSize ?? 18,
          child: Center(
            child: Icon(
              AppIcons.refresh,
              color: widget.color ?? p.muted,
              size: widget.iconSize ?? 18,
            ),
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
