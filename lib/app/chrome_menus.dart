part of 'chrome.dart';

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
    this.menuLeadingOf,
    this.menuSubtitleOf,
    this.menuTitle,
    this.highlightSelection = false,
    this.iconOf,
    this.width = 132,
    this.menuWidth,
    this.fixedMenuWidth = false,
    this.wrapMenuLabels = false,
    this.leading,
    this.trailing,
    this.semanticLabel,
    this.compact = false,
    this.subtitle,
    this.plain = false,
    this.alignMenuEnd = false,
    this.triggerBuilder,
  });

  final T value;
  final List<T> items;
  final String Function(T) labelOf;

  /// Optional longer labels for the menu, keeping the trigger compact.
  final String Function(T)? menuLabelOf;
  final String Function(T)? menuTrailingOf;
  final Widget Function(T)? menuLeadingOf;
  final String? Function(T)? menuSubtitleOf;
  final String? menuTitle;
  final bool highlightSelection;
  final IconData Function(T)? iconOf;
  final ValueChanged<T>? onChanged;
  final Widget? leading;
  final Widget? trailing;
  final String? semanticLabel;
  final bool compact;
  final String? subtitle;
  final bool plain;
  final bool alignMenuEnd;

  final Widget Function(BuildContext, bool, VoidCallback?, FocusNode)?
  triggerBuilder;
  final double? width;
  final double? menuWidth;
  final bool fixedMenuWidth;
  final bool wrapMenuLabels;

  static final List<VoidCallback> _closeHooks = [];
  static final Set<VoidCallback> _openHooks = {};

  /// Desktop back closes the transient menu before navigating a page.
  static bool dismissOpenMenu() {
    if (_openHooks.isEmpty) return false;
    closeAll();
    return true;
  }

  static void _register(VoidCallback close) => _closeHooks.add(close);

  static void _unregister(VoidCallback close) {
    _closeHooks.remove(close);
    _openHooks.remove(close);
  }

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
  ModalRoute<dynamic>? _sheetRoute;
  NavigatorState? _sheetNavigator;
  bool _sheetOpen = false;
  late final VoidCallback _closeHook;
  final _triggerFocus = FocusNode();
  bool _pointerActivation = false;
  final _tapGroup = Object();
  final _selectedOption = GlobalKey();
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
    _dismissSheet();
    if (_portal.isShowing) _portal.hide();
    _triggerFocus.dispose();
    _menuFocus.dispose();
    super.dispose();
  }

  void _dismissSheet() {
    final route = _sheetRoute;
    final navigator = _sheetNavigator;
    _sheetRoute = null;
    _sheetNavigator = null;
    if (route != null && navigator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigator.mounted && route.isActive) navigator.removeRoute(route);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  void _hide({bool restoreFocus = true}) {
    if (_sheetOpen) {
      _dismissSheet();
      return;
    }
    if (!_portal.isShowing) return;
    _portal.hide();
    AppShellSelect._openHooks.remove(_closeHook);
    if (mounted) {
      setState(() {});
      if (restoreFocus && !_pointerActivation) {
        _triggerFocus.requestFocus();
      } else {
        _triggerFocus.unfocus();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _hide(restoreFocus: false);
  }

  @override
  void didUpdateWidget(covariant AppShellSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onChanged == null ||
        widget.items.isEmpty ||
        widget.value != oldWidget.value ||
        !listEquals(widget.items, oldWidget.items)) {
      _hide(restoreFocus: false);
    }
  }

  Future<void> _openTouchChoice() async {
    FocusManager.instance.primaryFocus?.unfocus();
    AppShellSelect._closeOthers(_closeHook);
    setState(() => _sheetOpen = true);
    AppShellSelect._openHooks.add(_closeHook);
    final result = await _showChoiceSheet<T>(
      context,
      title: widget.menuTitle ?? widget.semanticLabel ?? '请选择',
      value: widget.value,
      items: List<T>.of(widget.items),
      labelOf: widget.menuLabelOf ?? widget.labelOf,
      trailingOf: widget.menuTrailingOf,
      leadingOf: widget.menuLeadingOf,
      subtitleOf: widget.menuSubtitleOf,
      iconOf: widget.iconOf,
      highlightSelection: widget.highlightSelection,
      onPointerMode: (value) => _pointerActivation = value,
      pointerAutofocus: _pointerActivation,
      onPresented: (context) {
        if (_sheetOpen) {
          _sheetRoute = ModalRoute.of(context);
          _sheetNavigator = Navigator.of(context);
        }
      },
    );
    _sheetRoute = null;
    _sheetNavigator = null;
    AppShellSelect._openHooks.remove(_closeHook);
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (!_pointerActivation) _triggerFocus.requestFocus();
    if (result != null && widget.items.contains(result.value)) {
      widget.onChanged?.call(result.value);
    }
  }

  void _toggle() {
    if (widget.onChanged == null || widget.items.isEmpty) return;
    if (_sheetOpen || _portal.isShowing) {
      _hide();
      return;
    }
    if (AppMobileUi.useTouchChrome(context)) {
      _openTouchChoice();
      return;
    }
    AppShellSelect._closeOthers(_closeHook);
    if (_pointerActivation) _triggerFocus.unfocus();
    _portal.show();
    AppShellSelect._openHooks.add(_closeHook);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final open = _portal.isShowing || _sheetOpen;
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
          final triggerWidth = info.childSize.width > 0
              ? info.childSize.width
              : (widget.width ?? 132);
          final defaultMaxWidth = triggerWidth > 320.0 ? triggerWidth : 320.0;
          final maxMenuWidth = (widget.menuWidth ?? defaultMaxWidth).clamp(
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
                fontWeight: FontWeight.w600,
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
          final minMenuWidth = triggerWidth.clamp(0.0, maxMenuWidth);
          final menuWidth = widget.fixedMenuWidth
              ? maxMenuWidth
              : (labelWidth + 88 + (widget.iconOf == null ? 0 : 28)).clamp(
                  minMenuWidth,
                  maxMenuWidth,
                );
          final left =
              (widget.alignMenuEnd
                      ? origin.dx + info.childSize.width - menuWidth
                      : origin.dx)
                  .clamp(12.0, overlaySize.width - 12 - menuWidth);
          final below =
              overlaySize.height -
              screen.padding.bottom -
              origin.dy -
              info.childSize.height -
              20;
          final above = origin.dy - screen.padding.top - 20;
          final openAbove = below < 150 && above > below;
          final maxHeight = (openAbove ? above : below).clamp(48.0, 320.0);
          final selectedIndex = widget.items.indexOf(widget.value);
          final initialIndex = selectedIndex < 0 ? 0 : selectedIndex;
          final rowHeight = (screen.textScaler.scale(14) * 22 / 14 + 16).clamp(
            40.0,
            double.infinity,
          );
          final initialOffset =
              (initialIndex * (rowHeight + 4) -
                      (maxHeight - AppMenuStyle.inset * 2 - rowHeight) / 2)
                  .clamp(0.0, double.infinity);
          return TapRegion(
            groupId: _tapGroup,
            onTapOutside: (event) {
              if (event.buttons & kBackMouseButton == 0) {
                _hide(restoreFocus: false);
              }
            },
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
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : AppMotion.fast,
                    curve: AppMotion.fastCurve,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.scale(
                        alignment: Alignment(
                          widget.alignMenuEnd ? 1 : -1,
                          openAbove ? 1 : -1,
                        ),
                        scale: .97 + .03 * value,
                        child: child,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        boxShadow: AppMenuStyle.shadows(context),
                      ),
                      child: Material(
                        color: p.popoverSurface,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: AppMenuStyle.shape(context),
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          width: menuWidth,
                          constraints: BoxConstraints(maxHeight: maxHeight),
                          padding: const EdgeInsets.all(AppMenuStyle.inset),
                          child: FocusScope(
                            node: _menuFocus,
                            autofocus: true,
                            onKeyEvent: (_, event) {
                              if (event is KeyDownEvent) {
                                _pointerActivation = false;
                              }
                              return KeyEventResult.ignored;
                            },
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
                                      _pointerActivation = false;
                                      _hide();
                                      return null;
                                    },
                                  ),
                                  NextFocusIntent:
                                      CallbackAction<NextFocusIntent>(
                                        onInvoke: (_) {
                                          _pointerActivation = false;
                                          _menuFocus.nextFocus();
                                          return null;
                                        },
                                      ),
                                  PreviousFocusIntent:
                                      CallbackAction<PreviousFocusIntent>(
                                        onInvoke: (_) {
                                          _pointerActivation = false;
                                          _menuFocus.previousFocus();
                                          return null;
                                        },
                                      ),
                                },
                                child: Listener(
                                  onPointerDown: (_) =>
                                      _pointerActivation = true,
                                  child: _SelectMenuViewport(
                                    selectedAnchor: _selectedOption,
                                    initialOffset: initialOffset,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (
                                          var i = 0;
                                          i < widget.items.length;
                                          i++
                                        ) ...[
                                          if (i > 0) const SizedBox(height: 4),
                                          KeyedSubtree(
                                            key: i == initialIndex
                                                ? _selectedOption
                                                : null,
                                            child: AppMenuOption(
                                              pointerAutofocus:
                                                  _pointerActivation,
                                              key: ValueKey(
                                                'shell-select-option-$i',
                                              ),
                                              showCheck: true,
                                              highlightSelection:
                                                  widget.highlightSelection,
                                              leading: widget.menuLeadingOf
                                                  ?.call(widget.items[i]),
                                              subtitle: widget.menuSubtitleOf
                                                  ?.call(widget.items[i]),
                                              leadingIcon: widget.iconOf?.call(
                                                widget.items[i],
                                              ),
                                              label:
                                                  (widget.menuLabelOf ??
                                                  widget.labelOf)(
                                                    widget.items[i],
                                                  ),
                                              trailing:
                                                  widget.menuTrailingOf?.call(
                                                    widget.items[i],
                                                  ) ??
                                                  '',
                                              wrap: widget.wrapMenuLabels,
                                              selected:
                                                  widget.items[i] ==
                                                  widget.value,
                                              autofocus:
                                                  widget.items[i] ==
                                                      widget.value ||
                                                  (i == 0 &&
                                                      !widget.items.contains(
                                                        widget.value,
                                                      )),
                                              onTap: () {
                                                if (!_portal.isShowing) return;
                                                _hide();
                                                widget.onChanged?.call(
                                                  widget.items[i],
                                                );
                                              },
                                            ),
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
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: TapRegion(
          groupId: _tapGroup,
          onTapOutside: (event) {
            if (_sheetOpen) return;
            if (event.buttons & kBackMouseButton != 0) return;
            _triggerFocus.unfocus();
            _hide(restoreFocus: false);
          },
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) _pointerActivation = false;
              return KeyEventResult.ignored;
            },
            child: Listener(
              onPointerDown: (_) => _pointerActivation = true,
              child: SizedBox(
                width: widget.width,
                child: Semantics(
                  label: widget.semanticLabel,
                  child:
                      widget.triggerBuilder?.call(
                        context,
                        open,
                        widget.onChanged == null || widget.items.isEmpty
                            ? null
                            : _toggle,
                        _triggerFocus,
                      ) ??
                      AppSelectTrigger(
                        label: widget.labelOf(widget.value),
                        subtitle: widget.subtitle,
                        plain: widget.plain,
                        leading:
                            widget.leading ??
                            (widget.iconOf == null
                                ? null
                                : Icon(
                                    widget.iconOf!(widget.value),
                                    size: 16,
                                    color: p.muted,
                                  )),
                        trailing: widget.trailing,
                        compact:
                            widget.compact ||
                            (widget.width != null && widget.width! < 110),
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
        ),
      ),
    );
  }
}

/// Opening reveals the current value. Keep subsequent scroll position through
/// viewport changes; resizing must not animate or chase the selected row.
class _SelectMenuViewport extends StatefulWidget {
  const _SelectMenuViewport({
    required this.selectedAnchor,
    required this.initialOffset,
    required this.child,
  });
  final GlobalKey selectedAnchor;
  final double initialOffset;
  final Widget child;

  @override
  State<_SelectMenuViewport> createState() => _SelectMenuViewportState();
}

class _SelectMenuViewportState extends State<_SelectMenuViewport> {
  late final _scroll = ScrollController(
    initialScrollOffset: widget.initialOffset,
    keepScrollOffset: false,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = widget.selectedAnchor.currentContext?.findRenderObject();
      if (target == null || !target.attached) return;
      // Wrapped labels can exceed the initial single-line estimate. Reveal only
      // this menu's viewport, never a settings list behind the overlay.
      _scroll.position.ensureVisible(target, alignment: .5);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(controller: _scroll, child: widget.child);
}

/// Shared inset option for filter and identity menus.
class AppMenuOption extends StatelessWidget {
  const AppMenuOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing = '',
    this.wrap = false,
    this.showCheck = false,
    this.leadingIcon,
    this.leading,
    this.highlightSelection = false,
    this.subtitle,
    this.danger = false,
    this.autofocus = false,
    this.pointerAutofocus = false,
  });

  final String label;
  final String trailing;
  final bool selected;
  final VoidCallback onTap;
  final bool wrap;
  final bool showCheck;
  final IconData? leadingIcon;
  final Widget? leading;
  final bool highlightSelection;
  final String? subtitle;
  final bool danger;
  final bool autofocus;

  /// Mouse-opened menus autofocus for navigation, without a keyboard highlight.
  final bool pointerAutofocus;

  @override
  Widget build(BuildContext context) => _AppSurfaceInteraction(
    onTap: onTap,
    autofocus: autofocus,
    pointerAutofocus: pointerAutofocus,
    builder: (context, states) {
      final p = AppPalette.of(context);
      final active =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused);
      final pressed = states.contains(WidgetState.pressed);
      final bg = pressed
          ? p.controlPressed
          : active
          ? p.hover
          : selected && highlightSelection
          ? p.accentSoft
          : AppPalette.clearOf(p.hover);
      final style = TextStyle(
        fontSize: AppDensity.isTouch(context)
            ? 17
            : (subtitle != null && leading != null ? 15 : 14),
        height: 1.5,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        // Single-cursor highlight lets the active target stand out while the
        // check mark and medium weight carry the persisted selection cleanly.
        color: danger ? p.danger : p.ink,
      );
      return Semantics(
        selected: selected,
        button: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppMotion.instant,
            curve: Curves.easeOut,
            constraints: BoxConstraints(
              minHeight: AppMobileUi.useTouchChrome(context)
                  ? AppMobileUi.choiceRow
                  : 40,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ] else if (leadingIcon != null) ...[
                  Icon(
                    leadingIcon,
                    size: 18,
                    color: danger
                        ? p.danger
                        : selected
                        ? p.primary
                        : p.muted,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      wrap
                          ? Text(label, style: style)
                          : AppTruncatedText(label, style: style),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: AppTypography.caption.copyWith(color: p.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    trailing,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      height: 22 / 12,
                      color: selected ? p.ink : p.muted,
                    ),
                  ),
                ],
                if (showCheck) ...[
                  const SizedBox(width: 12),
                  SizedBox.square(
                    dimension: 18,
                    child: selected
                        ? Icon(AppIcons.check, size: 18, color: p.primary)
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Shared contextual menu, with the same option shape as account/filter menus.
class AppActionMenu<T> extends StatelessWidget {
  const AppActionMenu({
    super.key,
    required this.tooltip,
    required this.actions,
    required this.onSelected,
    this.enabled = true,
    this.selectedValue,
  });
  final String tooltip;
  final List<AppMenuAction<T>> actions;
  final ValueChanged<T> onSelected;
  final bool enabled;
  final T? selectedValue;
  @override
  Widget build(BuildContext context) {
    return AppShellSelect<T?>(
      value: selectedValue,
      menuTitle: tooltip,
      items: [for (final action in actions) action.value],
      labelOf: (value) => actions.firstWhere((a) => a.value == value).label,
      menuSubtitleOf: (value) =>
          actions.firstWhere((a) => a.value == value).subtitle,
      iconOf: (value) =>
          actions.firstWhere((a) => a.value == value).icon ?? AppIcons.more,
      width: AppMobileUi.useTouchChrome(context) ? AppMobileUi.target : 32,
      menuWidth: 240,
      alignMenuEnd: true,
      onChanged: enabled
          ? (value) {
              if (value != null) onSelected(value);
            }
          : null,
      triggerBuilder: (context, open, toggle, focus) => AppIconButton(
        tooltip: tooltip,
        focusNode: focus,
        onPressed: toggle,
        icon: const Icon(AppIcons.more, size: 20),
        extent: AppMobileUi.useTouchChrome(context) ? AppMobileUi.target : 32,
        active: open && !AppMobileUi.useTouchChrome(context),
      ),
    );
  }
}

class AppMenuAction<T> {
  const AppMenuAction(this.value, this.label, {this.icon, this.subtitle});
  final T value;
  final String label;
  final IconData? icon;
  final String? subtitle;
}
