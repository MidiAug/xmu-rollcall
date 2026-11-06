import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'app_service_symbol.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Equal-weight directory controls. Static surfaces avoid per-entry blur.
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

  /// Horizontal layout for a narrow viewport.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = BorderRadius.circular(AppRadii.service);
    final symbol = AppServiceSymbol(
      key: const ValueKey('service-symbol'),
      icon: icon,
      size: compact ? 36 : 32,
    );
    final label = AppTruncatedText(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: p.ink,
      ),
    );
    final detail = Text(
      description,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 12,
        color: p.muted,
        height: 1.45,
      ),
    );
    final arrow = Icon(AppIcons.right, size: 13, color: p.muted);
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
          padding: const EdgeInsets.all(AppSpace.lg),
          onTap: onPressed,
          child: compact
              ? Row(
                  children: [
                    symbol,
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          label,
                          const SizedBox(height: AppSpace.xxs),
                          detail,
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    arrow,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [symbol, const Spacer(), arrow]),
                    const SizedBox(height: AppSpace.sm),
                    label,
                    const SizedBox(height: AppSpace.xxs),
                    detail,
                  ],
                ),
        ),
      ),
    );
  }
}
