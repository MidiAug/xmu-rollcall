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
    this.iconOf,
    this.width = 132,
    this.menuWidth,
    this.fixedMenuWidth = false,
    this.wrapMenuLabels = false,
    this.leading,
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
  final IconData Function(T)? iconOf;
  final ValueChanged<T>? onChanged;
  final Widget? leading;
  final String? semanticLabel;
  final bool compact;
  final String? subtitle;
  final bool plain;
  final bool alignMenuEnd;
  final Widget Function(BuildContext, bool, VoidCallback?, FocusNode)?
  triggerBuilder;
  final double width;
  final double? menuWidth;
  final bool fixedMenuWidth;
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
          final menuWidth = widget.fixedMenuWidth
              ? maxMenuWidth
              : (labelWidth + 88 + (widget.iconOf == null ? 0 : 28)).clamp(
                  widget.width.clamp(0.0, maxMenuWidth),
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
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : AppMotion.fast,
                    curve: AppMotion.fastCurve,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (openAbove ? -4 : 4) * (1 - value)),
                        child: child,
                      ),
                    ),
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
                                NextFocusIntent:
                                    CallbackAction<NextFocusIntent>(
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (
                                      var i = 0;
                                      i < widget.items.length;
                                      i++
                                    ) ...[
                                      if (i > 0) const SizedBox(height: 4),
                                      AppMenuOption(
                                        key: ValueKey('shell-select-option-$i'),
                                        leadingIcon: widget.iconOf?.call(
                                          widget.items[i],
                                        ),
                                        label:
                                            (widget.menuLabelOf ??
                                            widget.labelOf)(widget.items[i]),
                                        trailing:
                                            widget.menuTrailingOf?.call(
                                              widget.items[i],
                                            ) ??
                                            '',
                                        wrap: widget.wrapMenuLabels,
                                        selected:
                                            widget.items[i] == widget.value,
                                        autofocus:
                                            widget.items[i] == widget.value ||
                                            (i == 0 &&
                                                !widget.items.contains(
                                                  widget.value,
                                                )),
                                        onTap: () {
                                          _hide();
                                          widget.onChanged?.call(
                                            widget.items[i],
                                          );
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
                ),
              ],
            ),
          );
        },
        child: TapRegion(
          groupId: _tapGroup,
          onTapOutside: (_) {
            _triggerFocus.unfocus();
            _hide(restoreFocus: false);
          },
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
                          ? Icon(AppIcons.check, size: 18, color: p.primary)
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

/// Shared contextual menu, with the same option shape as account/filter menus.
class AppActionMenu<T> extends StatelessWidget {
  const AppActionMenu({
    super.key,
    required this.tooltip,
    required this.actions,
    required this.onSelected,
    this.enabled = true,
    this.framed = true,
  });
  final String tooltip;
  final List<AppMenuAction<T>> actions;
  final ValueChanged<T> onSelected;
  final bool enabled, framed;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppShellSelect<T?>(
      value: null,
      items: [for (final action in actions) action.value],
      labelOf: (value) => actions.firstWhere((a) => a.value == value).label,
      iconOf: (value) =>
          actions.firstWhere((a) => a.value == value).icon ?? AppIcons.more,
      width: 32,
      menuWidth: 240,
      alignMenuEnd: true,
      onChanged: enabled
          ? (value) {
              if (value != null) onSelected(value);
            }
          : null,
      triggerBuilder: (context, open, toggle, focus) => AppTooltipAnchor(
        child: IconButton(
          tooltip: tooltip,
          focusNode: focus,
          onPressed: toggle,
          icon: const Icon(AppIcons.more, size: 20),
          style: IconButton.styleFrom(
            backgroundColor: open ? p.selected : AppPalette.clearOf(p.primary),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            minimumSize: const Size(32, 32),
            padding: const EdgeInsets.all(6),
            side: framed ? BorderSide(color: p.borderStrong) : BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
      ),
    );
  }
}

class AppMenuAction<T> {
  const AppMenuAction(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}
