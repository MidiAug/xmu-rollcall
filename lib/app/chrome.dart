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
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: p.borderStrong),
      ),
      child: Icon(Icons.how_to_reg_outlined, size: size * 0.58, color: p.ink),
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
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) {
                if (PlatformHooks.isDesktop) {
                  windowManager.startDragging();
                }
              },
              onDoubleTap: () async {
                if (!PlatformHooks.isDesktop) return;
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                const BrandMark(size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '畅课签到',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                      Text(
                        'XMU TronClass',
                        style: TextStyle(fontSize: 11, color: p.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: p.hover,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: p.muted),
                    const SizedBox(width: 8),
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
              borderRadius: BorderRadius.circular(10),
              border: selected ? Border.all(color: p.borderStrong) : null,
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
    return ColoredBox(
      color: p.content,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(fontSize: 13, color: p.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ?trailing,
                ],
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
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.borderStrong),
              ),
              child: Icon(icon, color: p.muted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: p.ink,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
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
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: p.borderStrong),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }
}
