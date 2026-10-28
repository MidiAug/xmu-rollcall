part of 'chrome.dart';

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
  });

  final Future<void> Function() onRefresh;
  final Color? color;
  final double? iconSize;
  final String tooltip;
  final VisualDensity? visualDensity;
  final double? extent;

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
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _handle() async {
    if (_busy) return;
    setState(() => _busy = true);
    _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _spin
          ..stop()
          ..value = 0;
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppTooltipAnchor(
      child: IconButton(
        tooltip: widget.tooltip,
        style: PlatformHooks.isDesktop && !AppDensity.isTouch(context)
            ? IconButton.styleFrom(
                minimumSize: Size.square(widget.extent ?? 34),
                backgroundColor: p.surface,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.all(6),
                side: BorderSide(color: p.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              )
            : null,
        visualDensity: widget.visualDensity,
        onPressed: _busy ? null : _handle,
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
