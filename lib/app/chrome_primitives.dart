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
        data: IconThemeData(color: p.muted, size: 19),
        child: child,
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
  const AppTextLink(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon = AppIcons.right,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.textStyle,
  });
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style:
        TextButton.styleFrom(
          minimumSize: Size(0, AppMobileUi.useTouchChrome(context) ? 44 : 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: padding,
        ).copyWith(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          side: const WidgetStatePropertyAll(BorderSide.none),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)
                ? AppPalette.of(context).primary
                : AppPalette.of(context).muted,
          ),
          textStyle: WidgetStatePropertyAll(
            (textStyle ?? AppTypography.caption).copyWith(
              decoration: TextDecoration.none,
            ),
          ),
        ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (icon != null) ...[const SizedBox(width: 4), Icon(icon, size: 14)],
      ],
    ),
  );
}
