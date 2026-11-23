import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

class AssistEmptyRollcall extends StatelessWidget {
  const AssistEmptyRollcall({super.key});
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppGlassSurface(
      hero: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('签到动态', style: AppTypography.cardTitle.copyWith(color: p.ink)),
          const SizedBox(height: 18),
          Panel(
            inset: true,
            child: Text(
              '暂无进行中的签到',
              style: AppTypography.body.copyWith(color: p.muted),
            ),
          ),
        ],
      ),
    );
  }
}
