import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

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
      child: Icon(
        Icons.how_to_reg_outlined,
        size: size * 0.58,
        color: p.primary,
      ),
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
  });

  final Future<void> Function() onRefresh;
  final Color? color;
  final double? iconSize;
  final String tooltip;
  final VisualDensity? visualDensity;

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
    return IconButton(
      tooltip: widget.tooltip,
      visualDensity: widget.visualDensity,
      onPressed: _busy ? null : _handle,
      icon: RotationTransition(
        turns: _spin,
        child: Icon(
          Icons.refresh_rounded,
          color: widget.color ?? p.muted,
          size: widget.iconSize,
        ),
      ),
    );
  }
}

/// Drag / double-click maximize region for frameless desktop windows.
///
/// Fills its parent. Prefer a full-bar [Stack] layer so height is never
/// clipped to text metrics. Maximized → drag unmaximizes then moves
/// (native caption behavior that [windowManager.startDragging] alone skips).
class _WindowDragArea extends StatelessWidget {
  const _WindowDragArea();

  Future<void> _drag() async {
    if (!PlatformHooks.isDesktop) return;
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
        // Let Win32 apply restore bounds before SC_MOVE.
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      await windowManager.startDragging();
    } catch (_) {}
  }

  Future<void> _toggleMaximize() async {
    if (!PlatformHooks.isDesktop) return;
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => _drag(),
      onDoubleTap: _toggleMaximize,
      child: const SizedBox.expand(),
    );
  }
}

class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      height: AppLayout.titleBarHeight,
      color: p.surface,
      child: Stack(
        children: [
          if (PlatformHooks.isDesktop)
            const Positioned.fill(child: _WindowDragArea()),
          Row(
            children: [
              Expanded(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const BrandMark(size: 18),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: p.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (PlatformHooks.isDesktop) const _WindowButtons(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact pill segments — Linear / iOS style (soft track, elevated selected).
class AppSegment<T> {
  const AppSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// One cube in [AppChoiceCubes] (harness theme-cube pattern).
class AppChoiceCube<T> {
  const AppChoiceCube({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// Equal-width icon+label cubes — aligned with harness `settings-theme-cubes`.
class AppChoiceCubes<T> extends StatelessWidget {
  const AppChoiceCubes({
    super.key,
    required this.cubes,
    required this.value,
    required this.onChanged,
  });

  final List<AppChoiceCube<T>> cubes;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final compact = AppDensity.isTouch(context);
    final pad = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 20);

    return Row(
      children: [
        for (var i = 0; i < cubes.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpace.xs),
          Expanded(
            child: _ChoiceCubeButton<T>(
              cube: cubes[i],
              selected: cubes[i].value == value,
              padding: pad,
              palette: p,
              onTap: () {
                if (cubes[i].value != value) onChanged(cubes[i].value);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceCubeButton<T> extends StatelessWidget {
  const _ChoiceCubeButton({
    required this.cube,
    required this.selected,
    required this.padding,
    required this.palette,
    required this.onTap,
  });

  final AppChoiceCube<T> cube;
  final bool selected;
  final EdgeInsets padding;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.duration,
          curve: AppMotion.curve,
          padding: padding,
          decoration: BoxDecoration(
            color: selected ? palette.selected : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.group),
            border: Border.all(
              color: selected
                  ? palette.primary.withValues(alpha: 0.5)
                  : palette.borderStrong,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                cube.icon,
                size: 20,
                color: selected ? palette.primary : palette.muted,
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(
                cube.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: -0.1,
                  color: selected ? palette.primary : palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.expanded = false,
  });

  final List<AppSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: AppLayout.segmentHeight + 6,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadii.input),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final s in segments)
            expanded
                ? Expanded(child: _seg(context, p, dark, s))
                : _seg(context, p, dark, s),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, AppPalette p, bool dark, AppSegment<T> s) {
    final selected = s.value == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (!selected) onChanged(s.value);
          },
          child: AnimatedContainer(
            duration: AppMotion.duration,
            curve: AppMotion.curve,
            height: AppLayout.segmentHeight,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.control),
              boxShadow: selected && !dark
                  ? const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              s.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: -0.1,
                color: selected ? p.ink : p.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab-nested or full-route pages with a back-capable chrome bar.
///
/// Desktop **root** push (over the whole app): one bar with back + title |
/// actions + window controls.
///
/// Desktop **inside** a shell tab [Navigator]: back + title | actions only —
/// window controls stay on [AppTitleBar] (nested push must not duplicate them).
///
/// Mobile: [surface] extends under the status bar via [MediaQuery.viewPadding]
/// (not ancestor [SafeArea]); controls sit below that inset — see R-23.
class SubpageScaffold extends StatelessWidget {
  const SubpageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final canPop = Navigator.of(context).canPop();
    final desktop = PlatformHooks.isDesktop;
    final hostOnRootNavigator =
        Navigator.of(context, rootNavigator: true) == Navigator.of(context);
    final showWindowControls = desktop && hostOnRootNavigator;
    final barHeight = desktop ? AppLayout.titleBarHeight : 48.0;
    // Physical status-bar height — immune to ancestor SafeArea clearing padding.
    final statusTop =
        desktop ? 0.0 : MediaQuery.viewPaddingOf(context).top;
    final overlay = _overlayForSurface(p.surface);

    final barInner = SizedBox(
      height: barHeight,
      child: Stack(
        children: [
          if (showWindowControls)
            const Positioned.fill(child: _WindowDragArea()),
          Row(
            children: [
              if (canPop)
                IconButton(
                  tooltip: '返回',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: p.ink,
                    size: 18,
                  ),
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: desktop ? 13 : 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        color: p.ink,
                      ),
                    ),
                  ),
                ),
              ),
              ...?actions,
              if (showWindowControls) const _WindowButtons(),
              if (!desktop) const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );

    // Extend surface behind the status bar; inset only the control row (R-23).
    final bar = AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Material(
        color: p.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (statusTop > 0) SizedBox(height: statusTop),
            barInner,
          ],
        ),
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: p.canvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Container(height: 1, color: p.border),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Match Material [AppBar]: light surface → dark status icons, and vice versa.
SystemUiOverlayStyle _overlayForSurface(Color surface) {
  final brightness = ThemeData.estimateBrightnessForColor(surface);
  return brightness == Brightness.dark
      ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
      : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WinBtn(
          icon: Icons.remove,
          onTap: () => windowManager.minimize(),
          color: p.muted,
        ),
        _WinBtn(
          icon: Icons.crop_square,
          iconSize: 12,
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
    required this.icon,
    required this.onTap,
    required this.color,
    this.hover,
    this.hoverIcon,
    this.iconSize = 16,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color? hover;
  final Color? hoverIcon;
  final double iconSize;

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    final bg = _over ? (widget.hover ?? AppPalette.of(context).hover) : null;
    return MouseRegion(
      onEnter: (_) => setState(() => _over = true),
      onExit: (_) => setState(() => _over = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: AppLayout.titleBarHeight,
          color: bg,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: _over && widget.hoverIcon != null
                ? widget.hoverIcon
                : widget.color,
          ),
        ),
      ),
    );
  }
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.current,
    required this.onSelect,
    this.userLabel,
  });

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;
  final String? userLabel;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: AppLayout.sidebarWidth,
      color: p.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.sm,
              AppSpace.sm,
              AppSpace.sm,
              AppSpace.xs,
            ),
            child: Row(
              children: [
                const BrandMark(size: 28),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '畅课签到',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.15,
                          color: p.ink,
                        ),
                      ),
                      Text(
                        'XMU TronClass',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: p.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
            child: Column(
              children: [
                for (final d in AppDestination.values)
                  _NavCell(
                    destination: d,
                    selected: d == current,
                    onTap: () => onSelect(d),
                  ),
              ],
            ),
          ),
          const Spacer(),
          if (userLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.sm,
                0,
                AppSpace.sm,
                AppSpace.md,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: AppSpace.xs,
                ),
                decoration: BoxDecoration(
                  color: p.hover,
                  borderRadius: BorderRadius.circular(AppRadii.nav),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: p.muted),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Text(
                        userLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavCell extends StatefulWidget {
  const _NavCell({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavCell> createState() => _NavCellState();
}

class _NavCellState extends State<_NavCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final selected = widget.selected;
    final fill = selected
        ? p.selected
        : _hover
            ? p.hover
            : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.duration,
            curve: AppMotion.curve,
            height: AppDensity.navItemHeight(context),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppRadii.nav),
            ),
            child: Row(
              children: [
                Icon(
                  _icon(widget.destination),
                  size: 18,
                  color: selected ? p.primary : p.muted,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.destination.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: -0.1,
                    color: selected ? p.ink : p.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _icon(AppDestination d) => switch (d) {
        AppDestination.rollcall => Icons.how_to_reg_outlined,
        AppDestination.homework => Icons.assignment_outlined,
        AppDestination.settings => Icons.person_outline,
      };
}

class AppMobileNav extends StatelessWidget {
  const AppMobileNav({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bottom = AppDensity.mobileNavBottomInset(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: AppDensity.mobileBar,
          child: Row(
            children: [
              for (final d in AppDestination.values)
                Expanded(
                  child: _MobileItem(
                    destination: d,
                    selected: d == current,
                    onTap: () => onSelect(d),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileItem extends StatelessWidget {
  const _MobileItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = selected ? p.primary : p.muted;
    return InkWell(
      onTap: onTap,
      hoverColor: p.hover,
      splashColor: p.hover,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon(destination), size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            destination.label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? p.ink : p.muted,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(AppDestination d) => switch (d) {
        AppDestination.rollcall => Icons.how_to_reg_outlined,
        AppDestination.homework => Icons.assignment_outlined,
        AppDestination.settings => Icons.person_outline,
      };
}

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.showHeader = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final theme = Theme.of(context).textTheme;
    // Canvas extends under the status bar; inset content only (R-23).
    return ColoredBox(
      color: p.canvas,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader)
              SizedBox(
                height: AppLayout.pageHeaderHeight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.pageXOf(context),
                    16,
                    AppSpace.pageXOf(context),
                    12,
                  ),
                  child: Row(
                    // Top-align so title baseline is identical with/without trailing.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: (theme.titleLarge ?? const TextStyle())
                                  .copyWith(
                                color: p.ink,
                                height: 1.2,
                                leadingDistribution:
                                    TextLeadingDistribution.even,
                              ),
                            ),
                            const SizedBox(height: AppSpace.xxs),
                            Text(
                              subtitle ?? ' ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: (theme.bodySmall ?? const TextStyle())
                                  .copyWith(
                                color: p.muted,
                                height: 1.3,
                                leadingDistribution:
                                    TextLeadingDistribution.even,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Fixed trailing slot → title column width identical on every Tab.
                      SizedBox(
                        width: AppLayout.pageHeaderTrailingWidth,
                        height: 36,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: trailing == null
                              ? const SizedBox.shrink()
                              : IconTheme(
                                  data: IconThemeData(
                                    color: p.muted,
                                    size: 20,
                                  ),
                                  child: trailing!,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              child: Icon(icon, color: p.muted, size: 22),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
                color: p.ink,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: p.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding,
    this.outlined = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Rare: floating / overlay surfaces that need a hairline edge.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: outlined
            ? BorderSide(color: p.borderStrong)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpace.md),
        child: child,
      ),
    );
  }
}

/// Apple Settings–style group: optional outer header + inset surface.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.header,
    required this.children,
    this.footer,
  });

  final String? header;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xs,
              0,
              AppSpace.xs,
              AppSpace.sectionGap,
            ),
            child: Text(
              header!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                color: p.muted,
              ),
            ),
          ),
        ],
        Material(
          color: p.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.group),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: p.border,
                    indent: AppDensity.rowPadding(context).left,
                    endIndent: AppDensity.rowPadding(context).right,
                  ),
                children[i],
              ],
            ],
          ),
        ),
        if (footer != null) ...[
          const SizedBox(height: AppSpace.sectionGap),
          footer!,
        ],
      ],
    );
  }
}

/// One inset row inside [SettingsSection]. Height / padding follow [AppDensity].
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
    this.minHeight,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;

  /// Extra block under [subtitle] (e.g. selectable mono device id).
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final h = minHeight ?? AppDensity.rowHeight(context);
    final gap = AppDensity.rowInnerGap(context);
    final content = Padding(
      padding: AppDensity.rowPadding(context),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              IconTheme(
                data: IconThemeData(color: p.muted, size: 20),
                child: leading!,
              ),
              SizedBox(width: gap),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.15,
                      color: p.ink,
                    ),
                  ),
                  if (subtitleWidget != null) ...[
                    const SizedBox(height: AppSpace.xs),
                    subtitleWidget!,
                  ],
                  if (subtitle != null) ...[
                    SizedBox(height: subtitleWidget != null ? AppSpace.xxs : 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: p.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: gap),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: p.hover,
        splashColor: p.hover,
        highlightColor: Colors.transparent,
        child: content,
      ),
    );
  }
}
