import 'package:flutter/material.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

class ScheduleStatusChip extends StatelessWidget {
  const ScheduleStatusChip({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '待完善',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: p.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: content,
        ),
      ),
    );
  }
}
