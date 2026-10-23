import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:xmu_rollcall/app/desktop_shell_chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/user_check_icon.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

part 'chrome_controls.dart';
part 'chrome_settings.dart';
part 'chrome_select.dart';

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
    return AppTooltipAnchor(
      child: IconButton(
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
      ),
    );
  }
}

/// Drag region for frameless desktop windows (maximize disabled — size capped).
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
      child: const SizedBox.expand(),
    );
  }
}

/// Desktop window chrome. Brand mode, or nested-subpage mode (back + title |
/// actions) when a tab claims [DesktopShellChromeController] — Fluent single bar.
class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key, required this.title});

  /// Brand title when no nested subpage claim is active.
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final chrome = DesktopShellChromeScope.maybeOf(context);
    final claim = chrome?.activeClaim;

    return Container(
      height: AppLayout.titleBarHeight,
      color: p.surface,
      child: Stack(
        children: [
          if (PlatformHooks.isDesktop)
            const Positioned.fill(child: _WindowDragArea()),
          Row(
            children: [
              if (claim != null) ...[
                AppTooltipAnchor(
                  child: IconButton(
                    tooltip: '返回',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    onPressed: claim.onBack,
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: p.ink,
                      size: 18,
                    ),
                  ),
                ),
                Expanded(
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        claim.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.15,
                          color: p.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                // Isolate each action (often IconButton+Tooltip) — Windows AXTree
                // desyncs when adjacent tooltip overlays share a merged parent
                // (flutter/flutter#182444); hosting chrome makes this acute.
                if (claim.actions != null)
                  for (final action in claim.actions!)
                    AppTooltipAnchor(child: action),
              ] else
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
              if (claim == null &&
                  (chrome?.activeRootActions.isNotEmpty ?? false)) ...[
                for (final action in chrome!.activeRootActions)
                  AppTooltipAnchor(child: action),
                const SizedBox(width: 8),
                Container(width: 1, height: 16, color: p.borderStrong),
                const SizedBox(width: 8),
              ],
              if (PlatformHooks.isDesktop) const _WindowButtons(),
            ],
          ),
        ],
      ),
    );
  }
}

/// One option in the shared, single-selection segmented control.
class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Compact icon + label choices on one neutral track. Supports touch, keyboard
/// traversal and radio-group semantics without changing the surrounding layout.
class AppSegmentedControl<T> extends StatefulWidget {
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
  State<AppSegmentedControl<T>> createState() => _AppSegmentedControlState<T>();
}

class _AppSegmentedControlState<T> extends State<AppSegmentedControl<T>> {
  final _nodes = <FocusNode>[];

  void _syncNodes() {
    while (_nodes.length < widget.segments.length) {
      _nodes.add(FocusNode());
    }
    while (_nodes.length > widget.segments.length) {
      _nodes.removeLast().dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncNodes();
  }

  @override
  void didUpdateWidget(covariant AppSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNodes();
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.segments.isEmpty) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final focused = _nodes.indexWhere((node) => node.hasFocus);
    if (focused < 0) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final int next;
    if (key == LogicalKeyboardKey.arrowRight) {
      next = (focused + (rtl ? -1 : 1)) % _nodes.length;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      next = (focused + (rtl ? 1 : -1)) % _nodes.length;
    } else if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = _nodes.length - 1;
    } else {
      return KeyEventResult.ignored;
    }
    _nodes[next].requestFocus();
    _select(next);
    return KeyEventResult.handled;
  }

  void _select(int index) {
    final next = widget.segments[index].value;
    if (next != widget.value) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Focus(
      canRequestFocus: false,
      includeSemantics: false,
      onKeyEvent: _handleKey,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: p.content,
          border: Border.all(color: p.borderStrong),
          borderRadius: BorderRadius.circular(AppRadii.input),
        ),
        child: Row(
          mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.segments.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              if (widget.expanded)
                Expanded(child: _segment(i))
              else
                _segment(i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(int index) {
    final s = widget.segments[index];
    return _SegmentButton(
      key: ValueKey(s.value),
      label: s.label,
      icon: s.icon,
      selected: s.value == widget.value,
      focusNode: _nodes[index],
      onTap: () => _select(index),
    );
  }
}

class _SegmentButton extends StatefulWidget {
  const _SegmentButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.focusNode,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  State<_SegmentButton> createState() => _SegmentButtonState();
}

class _SegmentButtonState extends State<_SegmentButton> {
  var _focused = false;
  var _hovered = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final foreground = widget.selected ? p.primary : p.muted;
    final active = _hovered || _pressed;
    final radius = BorderRadius.circular(AppRadii.control);
    return Semantics(
      button: true,
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          focusNode: widget.focusNode,
          borderRadius: radius,
          onFocusChange: (v) => setState(() => _focused = v),
          onHover: (v) => setState(() => _hovered = v),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          onTap: widget.onTap,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppMotion.instant,
            curve: AppMotion.instantCurve,
            constraints: BoxConstraints(
              minHeight: AppDensity.isTouch(context) ? 44 : 36,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: AppDensity.isTouch(context) ? 8 : 4,
            ),
            decoration: BoxDecoration(
              color: widget.selected
                  ? p.selected
                  : active
                  ? p.hover
                  : AppPalette.clearOf(p.hover),
              borderRadius: radius,
              border: Border.all(
                color: _focused ? p.primary : AppPalette.clearOf(p.primary),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18, color: foreground),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: foreground),
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

/// Tab-nested or full-route pages with a back-capable chrome bar.
///
/// Desktop **root** push (over the whole app): one bar with back + title |
/// actions + window controls.
///
/// Desktop **inside** a shell tab [Navigator]: chrome is hosted by
/// [AppTitleBar] via [DesktopShellChromeController] (no second bar).
///
/// Mobile: [surface] extends under the status bar via [MediaQuery.viewPadding]
/// (not ancestor [SafeArea]); controls sit below that inset — see R-23.
class SubpageScaffold extends StatefulWidget {
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
  State<SubpageScaffold> createState() => _SubpageScaffoldState();
}

class _SubpageScaffoldState extends State<SubpageScaffold> {
  final Object _owner = Object();
  DesktopShellChromeController? _chrome;
  AppDestination? _tab;
  var _claimed = false;

  bool get _hostInTitleBar {
    if (!PlatformHooks.isDesktop) return false;
    final onRoot =
        Navigator.of(context, rootNavigator: true) == Navigator.of(context);
    if (onRoot) return false;
    return DesktopShellChromeScope.maybeOf(context, listen: false) != null &&
        ShellTabDestination.maybeOf(context) != null;
  }

  void _syncChromeClaim() {
    if (!_hostInTitleBar) {
      _releaseChrome();
      return;
    }
    final chrome = DesktopShellChromeScope.of(context, listen: false);
    final tab = ShellTabDestination.maybeOf(context)!;
    _chrome = chrome;
    _tab = tab;
    chrome.claim(
      tab: tab,
      owner: _owner,
      title: widget.title,
      onBack: () {
        if (context.mounted) Navigator.of(context).maybePop();
      },
      actions: widget.actions,
    );
    _claimed = true;
  }

  void _releaseChrome() {
    if (!_claimed) return;
    final chrome = _chrome;
    final tab = _tab;
    if (chrome != null && tab != null) {
      chrome.release(tab: tab, owner: _owner);
    }
    _claimed = false;
    _chrome = null;
    _tab = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncChromeClaim();
  }

  @override
  void didUpdateWidget(covariant SubpageScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.actions != widget.actions) {
      _syncChromeClaim();
    }
  }

  @override
  void dispose() {
    _releaseChrome();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final hostInTitleBar = _hostInTitleBar;

    if (hostInTitleBar) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: p.canvas,
        body: widget.body,
      );
    }

    final canPop = Navigator.of(context).canPop();
    final desktop = PlatformHooks.isDesktop;
    final hostOnRootNavigator =
        Navigator.of(context, rootNavigator: true) == Navigator.of(context);
    final showWindowControls = desktop && hostOnRootNavigator;
    final barHeight = desktop ? AppLayout.titleBarHeight : 48.0;
    // Physical status-bar height — immune to ancestor SafeArea clearing padding.
    final statusTop = desktop ? 0.0 : MediaQuery.viewPaddingOf(context).top;
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
                AppTooltipAnchor(
                  child: IconButton(
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
                  ),
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.title,
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
              if (widget.actions != null)
                for (final action in widget.actions!)
                  AppTooltipAnchor(child: action),
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
          Expanded(child: widget.body),
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
          label: '最小化',
          icon: Icons.remove,
          onTap: () => windowManager.minimize(),
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
    final bg = _over ? (widget.hover ?? AppPalette.of(context).hover) : null;
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
            highlightColor: AppPalette.of(context).hover,
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

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.current,
    required this.onSelect,
    this.userLabel,
    this.accountControl,
    this.hasUpdate = false,
  });

  final AppDestination current;
  final ValueChanged<AppDestination> onSelect;
  final String? userLabel;
  final Widget? accountControl;
  final bool hasUpdate;

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
            child:
                accountControl ??
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: AppSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: p.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppRadii.nav),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        userLabel != null
                            ? Icons.person_outline
                            : Icons.person_off_outlined,
                        size: 14,
                        color: p.muted,
                      ),
                      const SizedBox(width: AppSpace.xs),
                      Expanded(
                        child: Text(
                          userLabel ?? '未登录',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                      ),
                    ],
                  ),
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
                    hasUpdate: hasUpdate && d == AppDestination.settings,
                    onTap: () => onSelect(d),
                  ),
              ],
            ),
          ),
          const Spacer(),
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
    required this.hasUpdate,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool hasUpdate;

  @override
  State<_NavCell> createState() => _NavCellState();
}

class _NavCellState extends State<_NavCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final selected = widget.selected;
    final radius = BorderRadius.circular(AppRadii.nav);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            height: AppDensity.navItemHeight(context),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Neutral hover: opacity only (no Color.lerp across accent).
                  AnimatedOpacity(
                    opacity: !selected && _hover ? 1 : 0,
                    duration: AppMotion.instant,
                    curve: AppMotion.instantCurve,
                    child: ColoredBox(color: p.hover),
                  ),
                  // Selected accent: snap on/off — never lerp with gray.
                  if (selected) ColoredBox(color: p.selected),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: Row(
                      children: [
                        _NavigationIcon(
                          icon: _icon(widget.destination),
                          size: 18,
                          color: selected ? p.primary : p.muted,
                          hasUpdate: widget.hasUpdate,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.destination.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            letterSpacing: -0.1,
                            color: selected ? p.ink : p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppMotion.instant,
        curve: AppMotion.instantCurve,
        color: _pressed && !selected ? p.hover : AppPalette.clearOf(p.hover),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NavigationIcon(
              icon: _icon(widget.destination),
              size: 22,
              color: color,
              hasUpdate: widget.hasUpdate,
            ),
            const SizedBox(height: 2),
            Text(
              widget.destination.label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? p.ink : p.muted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
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

/// A quiet update hint that preserves the icon's layout and hit target.
class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({
    required this.icon,
    required this.size,
    required this.color,
    required this.hasUpdate,
  });

  final IconData icon;
  final double size;
  final Color color;
  final bool hasUpdate;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, size: size, color: color);
    if (!hasUpdate) return child;
    return Tooltip(
      message: '有新版本可更新',
      child: Badge(
        backgroundColor: AppPalette.of(context).primary,
        smallSize: 6,
        offset: const Offset(2, -2),
        child: child,
      ),
    );
  }
}

/// Shared choice menu used by filters, settings and update routes.
///
/// Self-contained overlay; opening one closes others via a light registry.
class AppShellSelect<T> extends StatefulWidget {
  const AppShellSelect({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.menuLabelOf,
    this.menuTrailingOf,
    this.width = 132,
    this.menuWidth,
    this.wrapMenuLabels = false,
    this.leading,
    this.semanticLabel,
    this.compact = false,
  });

  final T value;
  final List<T> items;
  final String Function(T) labelOf;

  /// Optional longer labels for the menu, keeping the trigger compact.
  final String Function(T)? menuLabelOf;
  final String Function(T)? menuTrailingOf;
  final ValueChanged<T>? onChanged;
  final Widget? leading;
  final String? semanticLabel;
  final bool compact;
  final double width;
  final double? menuWidth;
  final bool wrapMenuLabels;

  static final List<VoidCallback> _closeHooks = [];

  static void _register(VoidCallback close) => _closeHooks.add(close);

  static void _unregister(VoidCallback close) => _closeHooks.remove(close);

  static void _closeOthers(VoidCallback keep) {
    for (final h in List<VoidCallback>.of(_closeHooks)) {
      if (!identical(h, keep)) h();
    }
  }

  /// Dismiss transient menus before switching destinations or opening a page.
  static void closeAll() {
    for (final close in List<VoidCallback>.of(_closeHooks)) {
      close();
    }
  }

  @override
  State<AppShellSelect<T>> createState() => _AppShellSelectState<T>();
}

class _AppShellSelectState<T> extends State<AppShellSelect<T>>
    with WidgetsBindingObserver {
  final _portal = OverlayPortalController();
  late final VoidCallback _closeHook;
  final _triggerFocus = FocusNode();
  final _tapGroup = Object();
  final _menuFocus = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );

  @override
  void initState() {
    super.initState();
    _closeHook = () => _hide(restoreFocus: false);
    AppShellSelect._register(_closeHook);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    AppShellSelect._unregister(_closeHook);
    WidgetsBinding.instance.removeObserver(this);
    if (_portal.isShowing) _portal.hide();
    _triggerFocus.dispose();
    _menuFocus.dispose();
    super.dispose();
  }

  void _hide({bool restoreFocus = true}) {
    if (!_portal.isShowing) return;
    _portal.hide();
    if (mounted) {
      setState(() {});
      if (restoreFocus) _triggerFocus.requestFocus();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _hide(restoreFocus: false);
  }

  @override
  void didUpdateWidget(covariant AppShellSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onChanged == null || widget.items.isEmpty) {
      _hide(restoreFocus: false);
    }
  }

  void _toggle() {
    if (widget.onChanged == null || widget.items.isEmpty) return;
    if (_portal.isShowing) {
      _hide();
      return;
    }
    AppShellSelect._closeOthers(_closeHook);
    _portal.show();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final open = _portal.isShowing;
    return PopScope<void>(
      canPop: !open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hide();
      },
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _portal,
        overlayChildBuilder: (context, info) {
          final screen = MediaQuery.of(context);
          final origin = MatrixUtils.transformPoint(
            info.childPaintTransform,
            Offset.zero,
          );
          final overlaySize = info.overlaySize;
          final maxMenuWidth = (widget.menuWidth ?? widget.width).clamp(
            0.0,
            overlaySize.width - 24,
          );
          var labelWidth = 0.0;
          final painter = TextPainter(
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          );
          for (final item in widget.items) {
            painter.text = TextSpan(
              text: (widget.menuLabelOf ?? widget.labelOf)(item),
              style: DefaultTextStyle.of(context).style.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 22 / 14,
              ),
              children: [
                if ((widget.menuTrailingOf?.call(item) ?? '').isNotEmpty)
                  TextSpan(
                    text: '  ${widget.menuTrailingOf!(item)}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            );
            painter.layout();
            if (painter.width > labelWidth) labelWidth = painter.width;
          }
          painter.dispose();
          final menuWidth = (labelWidth + 88).clamp(
            widget.width.clamp(0.0, maxMenuWidth),
            maxMenuWidth,
          );
          final left = origin.dx.clamp(
            12.0,
            overlaySize.width - 12 - menuWidth,
          );
          final below =
              overlaySize.height -
              screen.padding.bottom -
              origin.dy -
              info.childSize.height -
              20;
          final above = origin.dy - screen.padding.top - 20;
          final openAbove = below < 150 && above > below;
          final maxHeight = (openAbove ? above : below).clamp(48.0, 320.0);
          return TapRegion(
            groupId: _tapGroup,
            onTapOutside: (_) => _hide(restoreFocus: false),
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  top: openAbove
                      ? null
                      : origin.dy + info.childSize.height + AppSpace.xs,
                  bottom: openAbove
                      ? overlaySize.height - origin.dy + AppSpace.xs
                      : null,
                  child: Material(
                    color: p.surface,
                    elevation: AppMenuStyle.elevation,
                    shadowColor: AppMenuStyle.shadow(context),
                    shape: AppMenuStyle.shape(context),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      width: menuWidth,
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      padding: const EdgeInsets.all(AppMenuStyle.inset),
                      child: FocusScope(
                        node: _menuFocus,
                        autofocus: true,
                        child: Shortcuts(
                          shortcuts: const {
                            SingleActivator(LogicalKeyboardKey.escape):
                                DismissIntent(),
                            SingleActivator(LogicalKeyboardKey.arrowDown):
                                NextFocusIntent(),
                            SingleActivator(LogicalKeyboardKey.arrowUp):
                                PreviousFocusIntent(),
                          },
                          child: Actions(
                            actions: {
                              DismissIntent: CallbackAction<DismissIntent>(
                                onInvoke: (_) {
                                  _hide();
                                  return null;
                                },
                              ),
                              NextFocusIntent: CallbackAction<NextFocusIntent>(
                                onInvoke: (_) {
                                  _menuFocus.nextFocus();
                                  return null;
                                },
                              ),
                              PreviousFocusIntent:
                                  CallbackAction<PreviousFocusIntent>(
                                    onInvoke: (_) {
                                      _menuFocus.previousFocus();
                                      return null;
                                    },
                                  ),
                            },
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    var i = 0;
                                    i < widget.items.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const SizedBox(height: 4),
                                    AppMenuOption(
                                      key: ValueKey('shell-select-option-$i'),
                                      label:
                                          (widget.menuLabelOf ??
                                          widget.labelOf)(widget.items[i]),
                                      trailing:
                                          widget.menuTrailingOf?.call(
                                            widget.items[i],
                                          ) ??
                                          '',
                                      wrap: widget.wrapMenuLabels,
                                      selected: widget.items[i] == widget.value,
                                      autofocus:
                                          widget.items[i] == widget.value,
                                      onTap: () {
                                        _hide();
                                        widget.onChanged?.call(widget.items[i]);
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: TapRegion(
          groupId: _tapGroup,
          child: SizedBox(
            width: widget.width,
            child: Semantics(
              label: widget.semanticLabel,
              child: AppSelectTrigger(
                label: widget.labelOf(widget.value),
                leading: widget.leading,
                compact: widget.compact || widget.width < 110,
                focusNode: _triggerFocus,
                open: open,
                onTap: widget.onChanged == null || widget.items.isEmpty
                    ? null
                    : _toggle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared inset option for filter and identity menus.
class AppMenuOption extends StatefulWidget {
  const AppMenuOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing = '',
    this.wrap = false,
    this.showCheck = false,
    this.leadingIcon,
    this.danger = false,
    this.autofocus = false,
  });

  final String label;
  final String trailing;
  final bool selected;
  final VoidCallback onTap;
  final bool wrap;
  final bool showCheck;
  final IconData? leadingIcon;
  final bool danger;
  final bool autofocus;

  @override
  State<AppMenuOption> createState() => _AppMenuOptionState();
}

class _AppMenuOptionState extends State<AppMenuOption> {
  var _hover = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final active = _hover || _focused;
    final bg = widget.selected
        ? p.selected
        : active
        ? p.hover
        : AppPalette.clearOf(p.hover);
    final style = TextStyle(
      fontSize: 14,
      height: 22 / 14,
      fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
      color: widget.danger
          ? p.danger
          : widget.selected
          ? p.primary
          : p.ink,
    );
    return Semantics(
      selected: widget.selected,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: InkWell(
            onTap: widget.onTap,
            autofocus: widget.autofocus,
            onFocusChange: (focused) => setState(() => _focused = focused),
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              constraints: BoxConstraints(
                minHeight: AppDensity.isTouch(context) ? 44 : 40,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Row(
                children: [
                  if (widget.leadingIcon != null) ...[
                    Icon(
                      widget.leadingIcon,
                      size: 18,
                      color: widget.danger
                          ? p.danger
                          : widget.selected
                          ? p.primary
                          : p.muted,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: widget.wrap
                        ? Text(widget.label, style: style)
                        : AppTruncatedText(widget.label, style: style),
                  ),
                  if (widget.trailing.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      widget.trailing,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        height: 22 / 12,
                        color: widget.selected ? p.primary : p.muted,
                      ),
                    ),
                  ],
                  if (widget.showCheck) ...[
                    const SizedBox(width: 12),
                    SizedBox.square(
                      dimension: 18,
                      child: widget.selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: p.primary,
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full text is available on hover/long press only when it is ellipsized.
class AppTruncatedText extends StatelessWidget {
  const AppTruncatedText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: bounds.maxWidth);
      final truncated = painter.didExceedMaxLines;
      painter.dispose();
      final child = Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
      return truncated ? Tooltip(message: text, child: child) : child;
    },
  );
}

/// Desktop: centered column capped at [maxWidth]. Touch: full-bleed pass-through.
///
/// Keeps list hubs readable on wide windows without a second layout tree.
class AppContentColumn extends StatelessWidget {
  const AppContentColumn({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (AppDensity.isTouch(context)) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: child,
        ),
      ),
    );
  }
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
    this.action,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;

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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: p.surfaceHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: p.muted, size: 22),
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                height: 1.25,
                color: p.ink,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4, color: p.muted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpace.md),
              action!,
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
        side: outlined ? BorderSide(color: p.borderStrong) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpace.md),
        child: child,
      ),
    );
  }
}
