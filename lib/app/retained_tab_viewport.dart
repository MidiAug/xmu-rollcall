import 'package:flutter/material.dart';

/// Retain routes and state without relaying every resize through hidden tabs.
/// Offstage alone still lays out its subtree. The frozen constraints and
/// MediaQuery keep that subtree unchanged until it becomes visible again.
class RetainedTabViewport extends StatefulWidget {
  const RetainedTabViewport({
    super.key,
    required this.active,
    required this.child,
  });
  final bool active;
  final Widget child;

  @override
  State<RetainedTabViewport> createState() => _RetainedTabViewportState();
}

class _RetainedTabViewportState extends State<RetainedTabViewport> {
  Size? _size;
  MediaQueryData? _media;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, bounds) {
        if (widget.active || _size == null) {
          _size = bounds.biggest;
          _media = media;
        }
        return Offstage(
          offstage: !widget.active,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: _size!.width,
            maxWidth: _size!.width,
            minHeight: _size!.height,
            maxHeight: _size!.height,
            child: MediaQuery(
              // Theme/accessibility changes still reach hidden routes. Only
              // window geometry waits until that tab is shown.
              data: media.copyWith(
                size: _media!.size,
                padding: _media!.padding,
                viewInsets: _media!.viewInsets,
                viewPadding: _media!.viewPadding,
              ),
              child: TickerMode(
                enabled: widget.active,
                child: ExcludeFocus(
                  excluding: !widget.active,
                  child: RepaintBoundary(child: widget.child),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
