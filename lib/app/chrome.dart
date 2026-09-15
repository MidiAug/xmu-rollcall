import 'package:flutter/material.dart';
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
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: p.borderStrong),
      ),
      child: Icon(Icons.how_to_reg_outlined, size: size * 0.58, color: p.ink),
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
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            height: AppLayout.segmentHeight,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 10 : 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: selected
                  ? Border.all(color: p.borderStrong)
                  : Border.all(color: Colors.transparent),
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

/// Full-route pages pushed over [AdaptiveShell].
///
/// Desktop: **one** chrome bar — back + title | actions + window controls.
/// Never puts view-mode segments in the title bar; never stacks a brand bar
/// under a second tool row. Drag layer covers the full bar height.
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
    final barHeight = desktop ? AppLayout.titleBarHeight : 48.0;

    final bar = Material(
      color: p.surface,
      child: SizedBox(
        height: barHeight,
        child: Stack(
          children: [
            if (desktop) const Positioned.fill(child: _WindowDragArea()),
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
                if (desktop) const _WindowButtons(),
                if (!desktop) const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: p.content,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Container(height: 1, color: p.borderStrong),
          Expanded(child: body),
        ],
      ),
    );
  }
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
            duration: const Duration(milliseconds: 120),
            height: AppLayout.navItemHeight,
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
                  color: selected ? p.ink : p.muted,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.destination.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
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
        AppDestination.history => Icons.history,
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
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.borderStrong)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
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
    final color = selected ? p.ink : p.muted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon(destination), size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            destination.label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(AppDestination d) => switch (d) {
        AppDestination.rollcall => Icons.how_to_reg_outlined,
        AppDestination.history => Icons.history,
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
    return ColoredBox(
      color: p.content,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            SizedBox(
              height: AppLayout.pageHeaderHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.pageX,
                  16,
                  AppSpace.pageX,
                  12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.titleLarge?.copyWith(color: p.ink),
                          ),
                          const SizedBox(height: AppSpace.xxs),
                          Text(
                            subtitle ?? ' ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodySmall?.copyWith(
                              color: p.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Fixed trailing slot → title column width identical on every Tab.
                    SizedBox(
                      width: AppLayout.pageHeaderTrailingWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: trailing == null
                            ? const SizedBox.shrink()
                            : IconTheme(
                                data: IconThemeData(color: p.muted, size: 20),
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
                border: Border.all(color: p.border),
              ),
              child: Icon(icon, color: p.muted),
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
  const Panel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpace.md),
        child: child,
      ),
    );
  }
}
