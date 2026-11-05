import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/desktop/desktop_page.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// A task column and an independent, full-height contextual column.
/// The page header belongs to the task column, so it cannot push context down.
class DesktopWorkspace extends StatelessWidget {
  const DesktopWorkspace({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.contextPanel,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final Widget? contextPanel;
  @override
  Widget build(BuildContext context) => Material(
    color: AppPalette.of(context).canvas,
    child: LayoutBuilder(
      builder: (context, bounds) {
        final main = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesktopPageHeader(
              title: title,
              subtitle: subtitle,
              inlineSubtitle: true,
              actions: actions,
            ),
            Expanded(child: child),
          ],
        );
        if (bounds.maxWidth < 680) return main;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: main),
            // Keep the task subtree in the same slot when context disappears.
            if (contextPanel != null)
              SizedBox(
                width: (bounds.maxWidth * .32).clamp(238, 340),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 22, 10, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: bounds.maxHeight - 46,
                    ),
                    child: contextPanel!,
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
