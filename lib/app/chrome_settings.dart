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
    final rowPad = rowPadding ?? AppDensity.rowPadding(context);
    final captionInset = rowPadding?.left ?? AppSpace.sm;
    final dividerIndent =
        rowPad.left + (hasLeading ? 20 + AppDensity.rowInnerGap(context) : 0);

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
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: p.muted),
              ),
            ),
          ],
          Material(
            color: p.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.group),
              side: BorderSide(color: p.border),
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
                  children[i],
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
class SettingsRow extends StatefulWidget {
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
  State<SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<SettingsRow> {
  var _hover = false;
  var _pressed = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final h = widget.minHeight ?? AppDensity.rowHeight(context);
    final gap = AppDensity.rowInnerGap(context);
    final interactive = widget.onTap != null;
    final wash = interactive && (_pressed || _hover || _focused)
        ? p.hover
        : AppPalette.clearOf(p.hover);

    final subtitle = widget.subtitle == null
        ? null
        : Text(
            widget.subtitle!,
            maxLines: widget.subtitleMaxLines,
            overflow: widget.subtitleMaxLines == null
                ? null
                : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          );
    Widget buildContent(bool below) => AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.fastCurve,
      color: wash,
      padding: widget.contentPadding ?? AppDensity.rowPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.leading != null) ...[
                  IconTheme(
                    data: IconThemeData(color: p.muted, size: 20),
                    child: widget.leading!,
                  ),
                  SizedBox(width: gap),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (widget.subtitleWidget != null) ...[
                        const SizedBox(height: AppSpace.xs),
                        widget.subtitleWidget!,
                      ],
                      if (subtitle != null && !below) ...[
                        SizedBox(
                          height: widget.subtitleWidget != null
                              ? AppSpace.xxs
                              : widget.subtitleSpacing,
                        ),
                        subtitle,
                      ],
                    ],
                  ),
                ),
                if (widget.trailing != null) ...[
                  SizedBox(width: gap),
                  widget.trailing!,
                ],
              ],
            ),
          ),
          if (subtitle != null && below) ...[
            SizedBox(height: widget.subtitleSpacing),
            subtitle,
          ],
        ],
      ),
    );
    final content = widget.stackSubtitleOnNarrow
        ? LayoutBuilder(
            builder: (context, constraints) => buildContent(
              widget.trailing != null && constraints.maxWidth < 360,
            ),
          )
        : buildContent(false);

    if (!interactive) return content;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onFocusChange: (focused) => setState(() => _focused = focused),
          splashFactory: NoSplash.splashFactory,
          focusColor: Colors.transparent,
          onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
          onTap: widget.onTap,
          child: content,
        ),
      ),
    );
  }
}
