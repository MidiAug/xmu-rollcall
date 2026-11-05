import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'homework_models.dart';

/// Shared inbox row for student tasks and instructor/assistant assignments.
class HomeworkListRow extends StatelessWidget {
  const HomeworkListRow({
    super.key,
    required this.item,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });
  final HomeworkItem item;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppHoverSurface(
      onTap: onTap,
      outlined: false,
      borderRadius: BorderRadius.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final wide = bounds.maxWidth >= 560 * scale;
          final metadata = trailing;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppIconSurface(child: Icon(AppIcons.document)),
              SizedBox(width: AppDensity.rowInnerGap(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty ? '未命名作业' : item.title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w500,
                        color: p.ink,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      AppTruncatedText(
                        subtitle,
                        style: AppTypography.caption.copyWith(color: p.muted),
                      ),
                    ],
                    if (!wide) ...[const SizedBox(height: 8), metadata],
                  ],
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 20),
                SizedBox(width: 280 * scale, child: metadata),
              ],
              const SizedBox(width: 12),
              Icon(AppIcons.right, size: 16, color: p.muted),
            ],
          );
        },
      ),
    );
  }
}
