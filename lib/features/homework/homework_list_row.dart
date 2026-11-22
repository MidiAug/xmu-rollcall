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
    this.compactTrailing,
    required this.onTap,
  });

  /// Align dividers with the title rather than a repeated decorative icon.
  static double titleInset(BuildContext context) => 1 + AppSpace.md;

  final HomeworkItem item;
  final String subtitle;
  final Widget trailing;
  final Widget? compactTrailing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppHoverSurface(
      onTap: onTap,
      outlined: false,
      quiet: true,
      borderRadius: BorderRadius.zero,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.md,
      ),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final wide = bounds.maxWidth >= 560 * scale;
          final metadata = trailing;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTruncatedText(
                      item.title.isEmpty ? '未命名作业' : item.title,
                      style: AppTypography.body.copyWith(
                        fontSize: AppDensity.isTouch(context) ? 16 : 14,
                        fontWeight: FontWeight.w600,
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
                    if (!wide) ...[
                      const SizedBox(height: 4),
                      AppTruncatedText(
                        item.dueAt == null
                            ? item.dueLabel
                            : '${item.dueLabel} 截止',
                        style: AppTypography.caption.copyWith(color: p.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (!wide) ...[
                const SizedBox(width: AppSpace.sm),
                compactTrailing ?? trailing,
              ],
              if (wide) ...[
                const SizedBox(width: AppSpace.xl),
                SizedBox(width: 264 * scale, child: metadata),
              ],
              const SizedBox(width: AppSpace.md),
              const Icon(AppIcons.right),
            ],
          );
        },
      ),
    );
  }
}
