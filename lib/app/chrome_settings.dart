part of 'chrome.dart';

/// Apple Settings–style group: optional outer header + inset surface.
///
/// Vertical rhythm (proximity): caption hugs its card ([AppSpace.sectionGap]);
/// groups separate via [AppSpace.settingsGroupTopOf] when [padTop] is true
/// (default). Pass [padTop]: false for the first group on a page.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.header,
    required this.children,
    this.footer,
    this.padTop = true,
    this.hasLeading = true,
    this.rowPadding,
    this.dividerIndent,
  });

  final String? header;
  final List<Widget> children;
  final Widget? footer;

  /// Insert space above this group (card → next caption). Off for page-first.
  final bool padTop;

  /// When rows have leading icons, indent dividers to the title column.
  final bool hasLeading;
  final EdgeInsets? rowPadding;
  final double? dividerIndent;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final touch = AppMobileUi.useTouchChrome(context);
    final rowPad = rowPadding ?? AppDensity.rowPadding(context);
    final leadingExtent = touch
        ? AppDensity.settingsTouchLeading
        : AppDensity.settingsLeading;
    const captionInset = 12.0;
    final dividerIndent =
        this.dividerIndent ??
        rowPad.left +
            (hasLeading ? leadingExtent + AppDensity.settingsInnerGap : 0);

    return Padding(
      padding: EdgeInsets.only(
        top: padTop ? AppSpace.settingsGroupTopOf(context) : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[AppSectionHeading(child: Text(header!))],
          Panel(
            outlined: true,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: p.divider,
                      indent: dividerIndent,
                      endIndent: rowPad.right,
                    ),
                  _SettingsControlTheme(child: children[i]),
                ],
              ],
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: AppSpace.sectionGap),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: captionInset),
              child: footer!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared caption grid for grouped cards, including composite course headings.
class AppSectionHeading extends StatelessWidget {
  const AppSectionHeading({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, AppSpace.sectionGap),
    child: DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppPalette.of(context).muted,
        fontWeight: FontWeight.w600,
      ),
      child: child,
    ),
  );
}

/// One inset row inside [SettingsSection]. Height / padding follow [AppDensity].
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.leading,
    required this.title,
    this.truncateTitle = false,
    this.subtitle,
    this.subtitleMaxLines,
    this.subtitleWidget,
    this.stackSubtitleOnNarrow = false,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.minHeight,
    this.contentPadding,
    this.subtitleSpacing = 4,
  });

  final Widget? leading;
  final String title;
  final bool truncateTitle;
  final String? subtitle;
  final int? subtitleMaxLines;

  /// Extra block under [subtitle] (e.g. selectable mono device id).
  final Widget? subtitleWidget;

  /// Keep supporting text readable beside a wide control on narrow pages.
  final bool stackSubtitleOnNarrow;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// A disabled action stays distinct from a passive row with child controls.
  final bool enabled;

  /// Minimum total row height on desktop, including its content padding.
  final double? minHeight;
  final EdgeInsetsGeometry? contentPadding;
  final double subtitleSpacing;

  @override
  Widget build(BuildContext context) {
    final row = _AppSurfaceInteraction(
      onTap: enabled ? onTap : null,
      builder: _buildRow,
    );
    return onTap == null
        ? row
        : Semantics(button: true, enabled: enabled, child: row);
  }

  Widget _buildRow(BuildContext context, Set<WidgetState> states) {
    final p = AppPalette.of(context);
    final focused = states.contains(WidgetState.focused);
    final pressed = states.contains(WidgetState.pressed);
    final hovered = states.contains(WidgetState.hovered);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.fast;
    final trailing = this.trailing;
    // Navigation feedback belongs to its indicator, not the whole settings
    // surface. Passive rows leave embedded controls' own states untouched.
    final Widget? indicator;
    if (enabled &&
        onTap != null &&
        trailing is Icon &&
        trailing.icon == AppIcons.right) {
      final color = pressed || focused
          ? p.primary
          : hovered
          ? p.ink
          : p.muted;
      indicator = TweenAnimationBuilder<Color?>(
        tween: ColorTween(begin: color, end: color),
        duration: duration,
        curve: AppMotion.fastCurve,
        builder: (context, color, _) => Icon(
          trailing.icon,
          key: trailing.key,
          size: trailing.size,
          color: color,
          semanticLabel: trailing.semanticLabel,
          textDirection: trailing.textDirection,
        ),
      );
    } else if (enabled && onTap != null && trailing != null) {
      // Composite navigation accessories (for example an update badge beside
      // a disclosure) inherit the same feedback without tinting the whole row.
      final color = pressed || focused
          ? p.primary
          : hovered
          ? p.ink
          : p.muted;
      indicator = TweenAnimationBuilder<Color?>(
        tween: ColorTween(begin: color, end: color),
        duration: duration,
        curve: AppMotion.fastCurve,
        child: trailing,
        builder: (context, color, child) => IconTheme.merge(
          data: IconThemeData(color: color),
          child: child!,
        ),
      );
    } else {
      indicator = trailing;
    }
    final touch = AppMobileUi.useTouchChrome(context);
    final h =
        minHeight ??
        (touch
            ? AppDensity.rowHeight(context)
            : AppDensity.settingsRowMinHeight);
    final gap = AppDensity.settingsInnerGap;
    final leadingExtent = touch
        ? AppDensity.settingsTouchLeading
        : AppDensity.settingsLeading;
    final hasSupporting = this.subtitle != null || subtitleWidget != null;
    final padding =
        (contentPadding ??
                (touch
                    ? AppDensity.rowPadding(context)
                    : EdgeInsets.symmetric(
                        horizontal: AppDensity.desktopRowPadH,
                        vertical: hasSupporting ? AppSpace.xs : AppSpace.xxs,
                      )))
            .resolve(Directionality.of(context));
    final subtitle = this.subtitle == null
        ? null
        : Text(
            this.subtitle!,
            maxLines: subtitleMaxLines,
            overflow: subtitleMaxLines == null ? null : TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: touch ? 13 : null),
          );
    Widget buildContent(bool below) => AnimatedContainer(
      duration: duration,
      curve: AppMotion.fastCurve,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: touch
                  ? h
                  : (h - padding.vertical).clamp(0.0, double.infinity),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  if (leading is Icon)
                    SizedBox.square(
                      dimension: leadingExtent,
                      child: IconTheme.merge(
                        data: IconThemeData(size: 20, color: p.muted),
                        child: leading!,
                      ),
                    )
                  else
                    SizedBox.square(
                      dimension: leadingExtent,
                      child: Center(child: leading!),
                    ),
                  SizedBox(width: gap),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (truncateTitle)
                        AppTruncatedText(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: touch ? 17 : null,
                                color: !enabled && onTap != null
                                    ? p.muted
                                    : null,
                              ),
                        )
                      else
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                fontSize: touch ? 17 : null,
                                color: !enabled && onTap != null
                                    ? p.muted
                                    : null,
                              ),
                        ),
                      if (subtitleWidget != null) ...[
                        const SizedBox(height: AppSpace.xs),
                        subtitleWidget!,
                      ],
                      if (subtitle != null && !below) ...[
                        SizedBox(
                          height: subtitleWidget != null
                              ? AppSpace.xxs
                              : subtitleSpacing,
                        ),
                        subtitle,
                      ],
                    ],
                  ),
                ),
                if (indicator != null) ...[SizedBox(width: gap), indicator],
              ],
            ),
          ),
          if (subtitle != null && below) ...[
            SizedBox(height: subtitleSpacing),
            subtitle,
          ],
        ],
      ),
    );
    final content = stackSubtitleOnNarrow
        ? LayoutBuilder(
            builder: (context, constraints) =>
                buildContent(trailing != null && constraints.maxWidth < 360),
          )
        : buildContent(false);

    return _AppFocusOutline(focused: focused, child: content);
  }
}

/// One weight, radius and height across controls embedded in settings rows.
class _SettingsControlTheme extends StatelessWidget {
  const _SettingsControlTheme({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final common = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(0, AppMobileUi.useTouchChrome(context) ? AppMobileUi.target : 36),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      iconSize: const WidgetStatePropertyAll(18),
    );
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: (theme.filledButtonTheme.style ?? const ButtonStyle()).merge(
            common,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: (theme.outlinedButtonTheme.style ?? const ButtonStyle())
              .merge(common)
              .merge(
                AppMobileUi.useTouchChrome(context)
                    ? ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(
                          AppPalette.of(context).controlSurface,
                        ),
                        side: WidgetStatePropertyAll(
                          BorderSide(
                            color: AppPalette.of(context).mobileOutline,
                          ),
                        ),
                      )
                    : const ButtonStyle(),
              ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: (theme.textButtonTheme.style ?? const ButtonStyle()).merge(
            common,
          ),
        ),
      ),
      child: child,
    );
  }
}
