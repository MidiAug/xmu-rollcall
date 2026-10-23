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
  });

  final String? header;
  final List<Widget> children;
  final Widget? footer;

  /// Insert space above this group (card → next caption). Off for page-first.
  final bool padTop;

  /// When rows have leading icons, indent dividers to the title column.
  final bool hasLeading;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final rowPad = AppDensity.rowPadding(context);
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
                AppSpace.sm,
                0,
                AppSpace.sm,
                AppSpace.sectionGap,
              ),
              child: Text(
                header!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 18 / 13,
                  letterSpacing: 0.15,
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
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
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
    this.trailing,
    this.onTap,
    this.minHeight,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final int? subtitleMaxLines;

  /// Extra block under [subtitle] (e.g. selectable mono device id).
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double? minHeight;

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

    final content = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.fastCurve,
      color: wash,
      padding: AppDensity.rowPadding(context),
      child: ConstrainedBox(
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.15,
                      color: p.ink,
                    ),
                  ),
                  if (widget.subtitleWidget != null) ...[
                    const SizedBox(height: AppSpace.xs),
                    widget.subtitleWidget!,
                  ],
                  if (widget.subtitle != null) ...[
                    SizedBox(
                      height: widget.subtitleWidget != null ? AppSpace.xxs : 4,
                    ),
                    Text(
                      widget.subtitle!,
                      maxLines: widget.subtitleMaxLines,
                      overflow: widget.subtitleMaxLines == null
                          ? null
                          : TextOverflow.ellipsis,
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
            if (widget.trailing != null) ...[
              SizedBox(width: gap),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );

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
