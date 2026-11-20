import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

enum AppStatusTone { success, warning, danger, neutral }

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge(
    this.label, {
    super.key,
    this.tone = AppStatusTone.neutral,
  });
  final String label;
  final AppStatusTone tone;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = switch (tone) {
      AppStatusTone.success => p.success,
      AppStatusTone.warning => p.warning,
      AppStatusTone.danger => p.danger,
      AppStatusTone.neutral => p.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: p.isDark ? .14 : .09),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: p.isDark ? .22 : .14)),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppTypography.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.3,
          color: color,
        ),
      ),
    );
  }
}
