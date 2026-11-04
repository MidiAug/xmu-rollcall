import 'package:flutter/material.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

/// Keeps adjacent Windows tooltip anchors in separate semantics containers.
/// The embedder can otherwise reject a merged AXTree (flutter/flutter#182444).
class AppTooltipAnchor extends StatelessWidget {
  const AppTooltipAnchor({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => PlatformHooks.isDesktop
      ? Semantics(container: true, child: child)
      : child;
}
