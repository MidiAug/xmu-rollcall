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
  });

  final String? header;
  final List<Widget> children;
  final Widget? footer;

  /// Insert space above this group (card → next caption). Off for page-first.
  final bool padTop;

  /// When rows have leading icons, indent dividers to the title column.
  final bool hasLeading;
  final EdgeInsets? rowPadding;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final touch = AppMobileUi.useTouchChrome(context);
    final rowPad = rowPadding ?? AppDensity.rowPadding(context);
    const captionInset = 12.0;
    final dividerIndent =
        rowPad.left + (hasLeading ? 36 + AppDensity.rowInnerGap(context) : 0);

    return Padding(
      padding: EdgeInsets.only(
        top: padTop ? AppSpace.settingsGroupTopOf(context) : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[
            Padding(
              // Caption aligns to card inset — same for every group (not past icons).
              padding: EdgeInsets.fromLTRB(
                captionInset,
                0,
                captionInset,
                AppSpace.sectionGap,
              ),
              child: Text(
                header!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: p.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          Material(
            color: p.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.group),
              side: BorderSide(color: touch ? p.mobileOutline : p.border),
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

/// One inset row inside [SettingsSection]. Height / padding follow [AppDensity].
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitleMaxLines,
    this.subtitleWidget,
    this.stackSubtitleOnNarrow = false,
    this.trailing,
    this.onTap,
    this.minHeight,
    this.contentPadding,
    this.subtitleSpacing = 4,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final int? subtitleMaxLines;

  /// Extra block under [subtitle] (e.g. selectable mono device id).
  final Widget? subtitleWidget;

  /// Keep supporting text readable beside a wide control on narrow pages.
  final bool stackSubtitleOnNarrow;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double? minHeight;
  final EdgeInsetsGeometry? contentPadding;
  final double subtitleSpacing;

  @override
  Widget build(BuildContext context) => _AppSurfaceInteraction(
    onTap: onTap,
    builder: (context, states) =>
        _buildRow(context, states.contains(WidgetState.focused)),
  );

  Widget _buildRow(BuildContext context, bool focused) {
    final p = AppPalette.of(context);
    final h = minHeight ?? AppDensity.rowHeight(context);
    final gap = AppDensity.rowInnerGap(context);
    final subtitle = this.subtitle == null
        ? null
        : Text(
            this.subtitle!,
            maxLines: subtitleMaxLines,
            overflow: subtitleMaxLines == null ? null : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          );
    Widget buildContent(bool below) => AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.fast,
      curve: AppMotion.fastCurve,
      foregroundDecoration: BoxDecoration(
        border: Border.all(
          color: focused ? p.focus : AppPalette.clearOf(p.focus),
        ),
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      padding: contentPadding ?? AppDensity.rowPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  if (leading is Icon)
                    SizedBox.square(
                      dimension: 36,
                      child: IconTheme.merge(
                        data: IconThemeData(size: 20, color: p.muted),
                        child: leading!,
                      ),
                    )
                  else
                    SizedBox.square(
                      dimension: 36,
                      child: Center(child: leading!),
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
                        style: Theme.of(context).textTheme.titleMedium,
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
                if (trailing != null) ...[SizedBox(width: gap), trailing!],
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

    return content;
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
