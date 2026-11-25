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
    this.showDescription = true,
    this.trailing,
  });
  final String title, description;
  final IconData icon;
  final VoidCallback onPressed;

  /// Horizontal desktop directory entry or the mobile teaching-assistant row.
  final bool compact;
  final bool showDescription;

  /// 右侧摘要（例如生活服务的上次余额），放在箭头之前。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = BorderRadius.circular(AppRadii.service);
    final touch = AppMobileUi.useTouchChrome(context);
    final symbol = AppServiceSymbol(
      key: const ValueKey('service-symbol'),
      icon: icon,
      size: touch ? 44 : 52,
    );
    final label = Text(
      title,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: 16,
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
        height: 1.45,
      ),
    );
    final arrow = Icon(AppIcons.right, size: 18, color: p.muted);
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
          padding: EdgeInsets.all(touch || compact ? AppSpace.md : AppSpace.xl),
          onTap: onPressed,
          child: compact
              ? ConstrainedBox(
                  constraints: BoxConstraints(minHeight: touch ? 44 : 60),
                  child: Row(
                    children: [
                      symbol,
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            label,
                            if (showDescription) ...[
                              const SizedBox(height: AppSpace.xxs),
                              detail,
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      if (trailing != null) ...[
                        trailing!,
                        const SizedBox(width: AppSpace.sm),
                      ],
                      arrow,
                    ],
                  ),
                )
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: showDescription
                        ? 94
                        : 44 +
                              12 +
                              MediaQuery.textScalerOf(context).scale(16) *
                                  1.4 *
                                  (MediaQuery.textScalerOf(context).scale(1) >
                                          1.2
                                      ? 2
                                      : 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          symbol,
                          if (trailing != null) ...[
                            const SizedBox(width: AppSpace.xs),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: trailing!,
                              ),
                            ),
                            const SizedBox(width: AppSpace.xs),
                          ] else
                            const Spacer(),
                          arrow,
                        ],
                      ),
                      const SizedBox(height: AppSpace.sm),
                      label,
                      if (showDescription) ...[
                        const SizedBox(height: AppSpace.xxs),
                        detail,
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
