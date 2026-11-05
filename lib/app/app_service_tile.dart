import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'app_service_symbol.dart';
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
    final symbol = AppServiceSymbol(
      key: const ValueKey('service-symbol'),
      icon: icon,
      size: compact ? 50 : 60,
    );
    final label = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: compact ? 15 : 16,
        fontWeight: FontWeight.w600,
        color: p.ink,
      ),
    );
    final detail = Text(
      description,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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
        opacity: 1,
        cacheShadows:
            !kIsWeb && defaultTargetPlatform == TargetPlatform.windows,
        borderRadius: radius,
        child: AppHoverSurface(
          outlined: false,
          backgroundColor: Colors.transparent,
          borderRadius: radius,
          padding: EdgeInsets.all(compact ? 18 : 24),
          onTap: onPressed,
          child: compact
              ? Row(
                  children: [
                    symbol,
                    const SizedBox(width: 16),
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
                  constraints: const BoxConstraints(minHeight: 80),
                  child: Row(
                    children: [
                      symbol,
                      const SizedBox(width: 22),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [label, const SizedBox(height: 8), detail],
                        ),
                      ),
                      const SizedBox(width: 12),
                      arrow,
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
