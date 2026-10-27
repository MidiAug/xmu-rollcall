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
        color: tone == AppStatusTone.success
            ? p.successSurface
            : color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppTypography.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.3,
          color: color,
        ),
      ),
    );
  }
}
