part of 'chrome.dart';

/// Drag region for frameless desktop windows.
///
/// Fills its parent. Prefer a full-bar [Stack] layer so height is never
/// clipped to text metrics.
class _WindowDragArea extends StatelessWidget {
  const _WindowDragArea();

  Future<void> _drag() async {
    if (!PlatformHooks.isDesktop) return;
    try {
      await windowManager.startDragging();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => _drag(),
      onDoubleTap: () async {
        if (!PlatformHooks.isDesktop) return;
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: const SizedBox.expand(),
    );
  }
}

/// App identity stays stable on ordinary routes. The full-window website viewer
/// supplies [onBack] and uses its document title in the center instead.
class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key, required this.title, this.onBack});
  final String title;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(
      height: AppLayout.titleBarHeight,
      child: ColoredBox(
        color: p.window,
        child: Stack(
          children: [
            if (PlatformHooks.isDesktop)
              const Positioned.fill(child: _WindowDragArea()),
            if (onBack != null)
              Positioned.fill(
                left: PlatformHooks.isDesktop ? 138 : 48,
                right: PlatformHooks.isDesktop ? 138 : 48,
                child: IgnorePointer(
                  child: Center(
                    child: AppTruncatedText(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: p.ink,
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                if (onBack != null)
                  AppIconButton(
                    tooltip: '返回软件',
                    hoverOutline: false,
                    extent: AppLayout.titleBarHeight,
                    padding: const EdgeInsets.all(6),
                    icon: const Icon(AppIcons.back, size: 16),
                    onPressed: onBack,
                  )
                else ...[
                  const SizedBox(width: 14),
                  const BrandMark(size: 18),
                  const SizedBox(width: 9),
                  IgnorePointer(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.ink,
                      ),
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(width: 10),
                    Text('开发版', style: TextStyle(fontSize: 10, color: p.muted)),
                  ],
                ],
                const Spacer(),
                if (PlatformHooks.isDesktop) const _WindowButtons(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButtons extends StatefulWidget {
  const _WindowButtons();
  @override
  State<_WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<_WindowButtons> with WindowListener {
  bool _maximized = false;
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _sync();
  }

  Future<void> _sync() async {
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted) setState(() => _maximized = maximized);
    } catch (_) {}
  }

  @override
  void onWindowMaximize() => _sync();
  @override
  void onWindowUnmaximize() => _sync();
  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WinBtn(
          label: '最小化',
          icon: Icons.remove,
          onTap: () => windowManager.minimize(),
          color: p.muted,
        ),
        _WinBtn(
          label: _maximized ? '恢复' : '最大化',
          icon: _maximized
              ? Icons.filter_none_rounded
              : Icons.crop_square_rounded,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
          color: p.muted,
        ),
        _WinBtn(
          label: '关闭窗口',
          icon: Icons.close,
          onTap: () => windowManager.close(),
          color: p.muted,
          hover: p.danger.withValues(alpha: 0.85),
          hoverIcon: Colors.white,
        ),
      ],
    );
  }
}

class _WinBtn extends StatefulWidget {
  const _WinBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
    this.hover,
    this.hoverIcon,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color? hover;
  final Color? hoverIcon;

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final bg = _over
        ? (widget.hover ?? AppPalette.of(context).ink.withValues(alpha: .14))
        : null;
    return AppTooltipAnchor(
      child: Tooltip(
        message: widget.label,
        child: Material(
          color: bg ?? Colors.transparent,
          child: InkWell(
            onHover: (value) => setState(() => _over = value),
            onTap: widget.onTap,
            splashFactory: NoSplash.splashFactory,
            hoverColor: Colors.transparent,
            highlightColor: AppPalette.of(context).ink.withValues(alpha: .22),
            focusColor: AppPalette.of(context).hover,
            child: SizedBox(
              width: 46,
              height: AppLayout.titleBarHeight,
              child: Icon(
                widget.icon,
                size: 16,
                color: _over && widget.hoverIcon != null
                    ? widget.hoverIcon
                    : widget.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
