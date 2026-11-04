import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Equal-weight directory entry; dense touch layout shares the same contract.
class AppServiceTile extends StatelessWidget {
  const AppServiceTile({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.onPressed,
    this.compact = false,
  });
  final String title, description;
  final IconData icon;
  final Color accent;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final mark = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .09),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: accent, size: 24),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: p.muted, height: 1.5),
        ),
      ],
    );
    return Semantics(
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.group),
          boxShadow: [
            BoxShadow(
              color: p.ink.withValues(alpha: p.isDark ? .04 : .035),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: AppHoverSurface(
          borderRadius: BorderRadius.circular(AppRadii.group),
          onTap: onPressed,
          padding: const EdgeInsets.all(20),
          child: compact
              ? Row(
                  children: [
                    mark,
                    const SizedBox(width: 18),
                    Expanded(child: text),
                    const SizedBox(width: 12),
                    Icon(AppIcons.right, size: 16, color: p.muted),
                  ],
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 106),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          mark,
                          const Spacer(),
                          Icon(AppIcons.right, size: 16, color: p.muted),
                        ],
                      ),
                      const SizedBox(height: 18),
                      text,
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
