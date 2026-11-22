import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

enum AppStatusTone { success, warning, danger, neutral, accent }

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge(
    this.label, {
    super.key,
    this.tone = AppStatusTone.neutral,
    this.pill = false,
  });
  static const _padding = EdgeInsets.symmetric(horizontal: 8, vertical: 3);
  static const _borderWidth = 1.0;
  static final _textStyle = AppTypography.caption.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Column owners measure the same typography, padding and border we paint.
  static double widthOf(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: DefaultTextStyle.of(context).style.merge(_textStyle),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width =
        painter.width.ceilToDouble() + _padding.horizontal + 2 * _borderWidth;
    painter.dispose();
    return width;
  }

  final String label;
  final AppStatusTone tone;
  final bool pill;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = switch (tone) {
      AppStatusTone.success => p.success,
      AppStatusTone.accent => p.primary,
      AppStatusTone.warning => p.warning,
      AppStatusTone.danger => p.danger,
      AppStatusTone.neutral => p.muted,
    };
    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: switch (tone) {
          AppStatusTone.success => p.successSurface,
          AppStatusTone.accent => p.accentSoft,
          AppStatusTone.danger => p.dangerSoft,
          AppStatusTone.neutral => p.pillMuted,
          AppStatusTone.warning => color.withValues(
            alpha: p.isDark ? .14 : .09,
          ),
        },
        borderRadius: BorderRadius.circular(pill ? 999 : 7),
        border: Border.all(
          width: _borderWidth,
          color: switch (tone) {
            AppStatusTone.success => p.successRim,
            AppStatusTone.accent => p.accentRim,
            AppStatusTone.danger => p.dangerRim,
            AppStatusTone.neutral => p.badgeRim,
            AppStatusTone.warning => color.withValues(
              alpha: p.isDark ? .22 : .14,
            ),
          },
        ),
      ),
      child: Text(label, maxLines: 1, style: _textStyle.copyWith(color: color)),
    );
  }
}
