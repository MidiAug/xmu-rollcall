part of 'chrome.dart';

/// Navigation is deliberately quiet; no second brand block above the destinations.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.current,
    required this.onSelect,
    this.userLabel,
    this.accountControl,
    this.hasUpdate = false,
    this.hasPendingPlace = false,
  });
  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;
  final String? userLabel;
  final Widget? accountControl;
  final bool hasUpdate;
  final bool hasPendingPlace;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(
      width: AppLayout.sidebarWidthOf(context),
      child: ColoredBox(
        color: p.sidebar,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 220,
              bottom: 118,
              child: IgnorePointer(
                child: ClipRect(
                  child: RepaintBoundary(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: CampusArtworkTreatment(
                        child: Image.asset(
                          'assets/illustrations/campus_sidebar.png',
                          width: AppLayout.sidebarWidthOf(context),
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.bottomCenter,
                          cacheWidth: 512,
                          filterQuality: FilterQuality.low,
                          opacity: AlwaysStoppedAnimation(p.isDark ? .28 : .36),
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 24, 10, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in desktopDestinations.where(
                    (d) => d != AppDestination.settings,
                  ))
                    _DesktopNavItem(
                      destination: d,
                      hasPendingPlace:
                          hasPendingPlace && d == AppDestination.timetable,
                      selected: d == current,
                      onTap: () => onSelect(d),
                    ),
                  const Spacer(),
                  Divider(color: p.border, height: 16),
                  _DesktopNavItem(
                    destination: AppDestination.settings,
                    selected: current == AppDestination.settings,
                    hasUpdate: hasUpdate,
                    onTap: () => onSelect(AppDestination.settings),
                  ),
                  const SizedBox(height: 2),
                  accountControl ??
                      Row(
                        children: [
                          Icon(
                            Icons.account_circle_outlined,
                            color: p.muted,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              userLabel ?? '未登录',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.hasUpdate = false,
    this.hasPendingPlace = false,
  });
  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool hasUpdate;
  final bool hasPendingPlace;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: Tooltip(
          message: hasPendingPlace
              ? '有上课地点未定位，请在地图上标记'
              : hasUpdate
              ? '有新版本可更新'
              : '',
          child: SizedBox(
            height: 40,
            child: Stack(
              children: [
                Positioned.fill(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor: p.ink,
                      backgroundColor: selected ? p.selected : null,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onTap,
                    child: Row(
                      children: [
                        _NavigationIcon(
                          icon: selected
                              ? destination.selectedIcon
                              : destination.icon,
                          size: 24,
                          color: selected ? p.navigationAccent : p.ink,
                          hasUpdate: false,
                          hint: hasPendingPlace
                              ? '有上课地点未定位，请在地图上标记'
                              : '有新版本可更新',
                          dotSize: 4,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            destination.desktopLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 7,
                          height: 7,
                          child: hasUpdate || hasPendingPlace
                              ? Container(
                                  key: ValueKey(
                                    'desktop-notice-${destination.id}',
                                  ),
                                  decoration: BoxDecoration(
                                    color: p.primary,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    left: 0,
                    top: 6,
                    bottom: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.navigationAccent,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const SizedBox(width: 3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppMobileNav extends StatelessWidget {
  const AppMobileNav({
    super.key,
    required this.current,
    required this.onSelect,
    this.hasUpdate = false,
  });

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;
  final bool hasUpdate;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bottom = AppDensity.mobileNavBottomInset(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.mobileOutline)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: AppDensity.mobileBar,
          child: Row(
            children: [
              for (final d in mobileDestinations)
                Expanded(
                  child: _MobileItem(
                    destination: d,
                    selected: d == current,
                    hasUpdate: hasUpdate && d == AppDestination.settings,
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

class _MobileItem extends StatefulWidget {
  const _MobileItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.hasUpdate,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool hasUpdate;

  @override
  State<_MobileItem> createState() => _MobileItemState();
}

class _MobileItemState extends State<_MobileItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final selected = widget.selected;
    final color = selected ? p.primary : p.muted;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: AppMotion.instant,
          curve: AppMotion.instantCurve,
          opacity: _pressed ? .7 : 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _NavigationIcon(
                icon: selected
                    ? widget.destination == AppDestination.settings
                          ? AppIcons.personSelected
                          : widget.destination.selectedIcon
                    : _icon(widget.destination),
                size: 22,
                color: color,
                hasUpdate: widget.hasUpdate,
                dotSize: 5,
              ),
              const SizedBox(height: 2),
              Text(
                widget.destination.label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(AppDestination d) => switch (d) {
    AppDestination.rollcall => AppIcons.rollcall,
    AppDestination.homework => AppIcons.homework,
    AppDestination.settings => AppIcons.person,
    AppDestination.timetable => AppIcons.calendar,
    AppDestination.campusTools => AppIcons.tools,
  };
}

/// A compact settings hint that preserves the icon's layout and hit target.
class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({
    required this.icon,
    required this.size,
    required this.color,
    required this.hasUpdate,
    required this.dotSize,
    this.hint = '有新版本可更新',
  });

  final String hint;
  final double dotSize;
  final IconData icon;
  final double size;
  final Color color;
  final bool hasUpdate;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, size: size, color: color);
    if (!hasUpdate) return child;
    return Tooltip(
      message: hint,
      child: Badge(
        backgroundColor: AppPalette.of(context).primary,
        smallSize: dotSize,
        offset: const Offset(1, -1),
        child: child,
      ),
    );
  }
}
