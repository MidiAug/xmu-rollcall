part of 'chrome.dart';

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
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (AppDensity.isTouch(context)) return child;
    return Align(
      alignment: alignment,
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

/// Keeps the page viewport full width while its scroll content stays readable.
/// Apply the builder's content insets to scroll padding (or sliver padding), so
/// Flutter's native scrollbar remains at the viewport edge and stays draggable.
class AppPageViewport extends StatelessWidget {
  const AppPageViewport({
    super.key,
    required this.builder,
    this.maxWidth = AppLayout.contentMaxWidth,
  });

  final double maxWidth;
  final Widget Function(BuildContext context, EdgeInsets contentInsets) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final gutter = AppDensity.isTouch(context)
          ? 0.0
          : ((bounds.maxWidth - maxWidth) / 2).clamp(0.0, double.infinity);
      return builder(context, EdgeInsets.symmetric(horizontal: gutter));
    },
  );
}

class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.headerLeading,
    this.onBack,
    required this.child,
    this.showHeader = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? headerLeading;
  final VoidCallback? onBack;
  final Widget child;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final theme = Theme.of(context).textTheme;
    if (PlatformHooks.isDesktop && !AppMobileUi.useTouchChrome(context)) {
      return DesktopPage(
        title: title,
        headerLeading: headerLeading,
        showHeader: showHeader,
        subtitle: subtitle,
        onBack: onBack,
        actions: trailing == null ? const [] : [trailing!],
        child: child,
      );
    }
    // Canvas extends under the status bar; inset content only (R-23).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayForSurface(p.pageBackground(context)),
      child: ColoredBox(
        color: p.pageBackground(context),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHeader)
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppLayout.pageHeaderHeight,
                  ),
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
                        if (onBack != null) ...[
                          AppIconButton(
                            tooltip: '返回',
                            onPressed: onBack,
                            icon: const Icon(AppIcons.back),
                          ),
                          const SizedBox(width: AppSpace.xs),
                        ],
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
                                    data: IconThemeData(
                                      color: p.muted,
                                      size: 20,
                                    ),
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

  /// Content groups use a quiet edge; floating surfaces own their elevation.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppMobileUi.useTouchChrome(context)
              ? AppMobileUi.panelRadius
              : AppRadii.card,
        ),
        side: AppMobileUi.useTouchChrome(context) || outlined
            ? BorderSide(
                color: MediaQuery.highContrastOf(context)
                    ? p.muted
                    : AppMobileUi.useTouchChrome(context)
                    ? p.mobileOutline
                    : p.surfaceBorder,
              )
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpace.md),
        child: child,
      ),
    );
  }
}
