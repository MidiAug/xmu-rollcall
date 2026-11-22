import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// Identity context shared by both production rollcall layouts.
class AssistIdentityHeader extends StatelessWidget {
  const AssistIdentityHeader({super.key, required this.identity});
  final AssistIdentity identity;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Row(
      children: [
        AppIdentityAvatar(name: identity.displayName, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTruncatedText(
                identity.displayName,
                style: AppTypography.cardTitle.copyWith(color: p.ink),
              ),
              const SizedBox(height: 6),
              const AppStatusBadge('协助身份'),
            ],
          ),
        ),
      ],
    );
  }
}

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
