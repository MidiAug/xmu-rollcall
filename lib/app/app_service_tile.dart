import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Equal-weight service controls on translucent surfaces, without per-tile blur.
class AppServiceTile extends StatelessWidget {
  const AppServiceTile({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onPressed,
    this.compact = false,
  });
  final String title, description;
  final IconData icon;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = BorderRadius.circular(AppRadii.service);
    final symbol = Container(
      key: const ValueKey('service-symbol'),
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(AppRadii.group),
        border: Border.all(color: p.isDark ? p.border : Colors.white),
      ),
      child: Icon(icon, size: 28, color: p.ink),
    );
    final label = Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: p.ink,
      ),
    );
    final detail = Text(
      description,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 13,
        color: p.muted,
        height: 1.5,
      ),
    );
    final arrow = Icon(AppIcons.right, size: 14, color: p.muted);
    return Semantics(
      button: true,
      child: AppGlassSurface(
        blur: 0,
        opacity: .84,
        borderRadius: radius,
        child: AppHoverSurface(
          outlined: false,
          backgroundColor: Colors.transparent,
          borderRadius: radius,
          padding: const EdgeInsets.all(18),
          onTap: onPressed,
          child: compact
              ? Row(
                  children: [
                    symbol,
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [label, const SizedBox(height: 6), detail],
                      ),
                    ),
                    const SizedBox(width: 12),
                    arrow,
                  ],
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 100),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [symbol, const Spacer(), arrow]),
                      const SizedBox(height: 10),
                      label,
                      const SizedBox(height: 5),
                      detail,
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
