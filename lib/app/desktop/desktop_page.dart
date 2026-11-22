import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_icon_button.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Content-owned page header. Nothing is registered with the native window bar.
class DesktopPageHeader extends StatelessWidget {
  const DesktopPageHeader({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.subtitleWidget,
    this.onBack,
    this.inlineSubtitle = false,
    this.keepActionsInline = false,
    this.actions = const [],
  });
  final String title;
  final Widget? leading;
  final String? subtitle;
  final Widget? subtitleWidget;
  final VoidCallback? onBack;
  final bool inlineSubtitle;
  final bool keepActionsInline;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: inlineSubtitle
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.center,
            children: [
              if (onBack != null) ...[
                AppIconButton(
                  tooltip: '返回',
                  onPressed: onBack,
                  icon: const Icon(AppIcons.back),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading != null)
                      leading!
                    else
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.pageTitle.copyWith(color: p.ink),
                      ),
                    if (subtitleWidget != null && !inlineSubtitle) ...[
                      const SizedBox(height: 8),
                      subtitleWidget!,
                    ] else if (subtitle != null && !inlineSubtitle) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 13, color: p.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (subtitle != null && inlineSubtitle) ...[
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    subtitle!,
                    style: AppTypography.control.copyWith(color: p.ink),
                  ),
                ),
              ],
            ],
          );
          final controls = Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          );
          if (!keepActionsInline &&
              constraints.maxWidth <
                  (inlineSubtitle ? 300 + actions.length * 52 : 420) *
                      MediaQuery.textScalerOf(context).scale(1) &&
              actions.isNotEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [heading, const SizedBox(height: 16), controls],
            );
          }
          return Row(
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Align(alignment: Alignment.centerLeft, child: heading),
                ),
              ),
              if (actions.isNotEmpty) ...[const SizedBox(width: 20), controls],
            ],
          );
        },
      ),
    );
  }
}

/// One surface and one header for desktop roots and nested routes alike.
class DesktopPage extends StatelessWidget {
  const DesktopPage({
    super.key,
    required this.title,
    required this.child,
    this.headerLeading,
    this.showHeader = true,
    this.subtitle,
    this.subtitleWidget,
    this.onBack,
    this.actions = const [],
  });
  final String title;
  final Widget? headerLeading;
  final bool showHeader;
  final String? subtitle;
  final Widget? subtitleWidget;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: AppPalette.of(context).canvas,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          DesktopPageHeader(
            title: title,
            leading: headerLeading,
            subtitle: subtitle,
            subtitleWidget: subtitleWidget,
            onBack: onBack,
            actions: actions,
          ),
        Expanded(child: child),
      ],
    ),
  );
}
