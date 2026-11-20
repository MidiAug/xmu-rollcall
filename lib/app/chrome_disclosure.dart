part of 'chrome.dart';

/// Quiet, keyboard-operable disclosure shared by settings and reading panels.
class AppDisclosure extends StatefulWidget {
  const AppDisclosure({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.headerPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.bodyKey,
    this.headerKey,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final EdgeInsetsGeometry headerPadding, contentPadding;
  final Key? bodyKey, headerKey;

  @override
  State<AppDisclosure> createState() => _AppDisclosureState();
}

class _AppDisclosureState extends State<AppDisclosure> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.enter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _expanded,
          button: true,
          child: AppHoverSurface(
            key: widget.headerKey,
            quiet: true,
            outlined: false,
            backgroundColor: Colors.transparent,
            padding: widget.headerPadding,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.control.copyWith(color: p.ink),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle!,
                          style: AppTypography.caption.copyWith(
                            color: p.muted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedRotation(
                  turns: _expanded ? .5 : 0,
                  duration: duration,
                  curve: AppMotion.enterCurve,
                  child: const Icon(AppIcons.down, size: 18),
                ),
              ],
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: _expanded ? 1 : 0),
          duration: duration,
          curve: AppMotion.enterCurve,
          builder: (context, value, child) => value == 0
              ? SizedBox.shrink(key: widget.bodyKey)
              : ClipRect(
                  key: widget.bodyKey,
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: value,
                    child: Opacity(
                      opacity: value,
                      child: IgnorePointer(
                        ignoring: !_expanded,
                        child: ExcludeFocus(
                          excluding: !_expanded,
                          child: ExcludeSemantics(
                            excluding: !_expanded,
                            child: child!,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          child: Padding(
            padding: widget.contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
        ),
      ],
    );
  }
}
