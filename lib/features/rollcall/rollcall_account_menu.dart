import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

class RollcallAccountMenu extends StatelessWidget {
  const RollcallAccountMenu({
    super.key,
    required this.value,
    required this.identities,
    required this.ownerName,
    required this.onChanged,
    this.watchingAccounts = const {},
    this.width = 180,
    this.sidebar = false,
    this.masthead = false,
  });

  /// Uses the menu ID: zero for the owner, otherwise the assist user ID.
  final Set<int> watchingAccounts;
  final int value;
  final List<AssistIdentity> identities;
  final String ownerName;
  final ValueChanged<int> onChanged;
  final double width;
  final bool sidebar;
  final bool masthead;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: AppShellSelect<int>(
      semanticLabel: '切换签到账号',
      key: const ValueKey('rollcall-identity-menu'),
      width: width,
      menuWidth: 220,
      triggerBuilder:
          masthead && Theme.of(context).platform == TargetPlatform.android
          ? (context, open, toggle, focus) {
              final p = AppPalette.of(context);
              final name = value == 0
                  ? ownerName
                  : identities.firstWhere((e) => e.userId == value).displayName;
              return TextButton(
                focusNode: focus,
                onPressed: identities.isEmpty ? null : toggle,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  foregroundColor: p.ink,
                  disabledForegroundColor: p.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.person, size: 18, color: p.primary),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (identities.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(AppIcons.down, size: 13, color: p.muted),
                    ],
                  ],
                ),
              );
            }
          : null,
      plain: sidebar,
      compact: sidebar,
      subtitle: sidebar ? (value == 0 ? '主账号' : '协助账号') : null,
      value: value,
      items: [0, for (final identity in identities) identity.userId],
      labelOf: (id) => id == 0
          ? ownerName
          : identities.firstWhere((item) => item.userId == id).displayName,
      menuTrailingOf: (id) => watchingAccounts.contains(id) ? '值守中' : '',
      iconOf: watchingAccounts.isEmpty
          ? null
          : (id) => watchingAccounts.contains(id)
                ? AppIcons.guard
                : AppIcons.person,
      trailing: watchingAccounts.contains(value)
          ? AppTooltipAnchor(
              child: Tooltip(
                message: '值守中',
                child: Icon(
                  AppIcons.guard,
                  size: 16,
                  color: AppPalette.of(context).primary,
                ),
              ),
            )
          : null,
      leading: sidebar
          ? CircleAvatar(
              radius: 16,
              backgroundColor: AppPalette.of(context).selected,
              child: Text(
                (value == 0
                            ? ownerName
                            : identities
                                  .firstWhere((item) => item.userId == value)
                                  .displayName)
                        .characters
                        .firstOrNull ??
                    '我',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.of(context).primary,
                ),
              ),
            )
          : Icon(
              AppIcons.person,
              size: 18,
              color: AppPalette.of(context).primary,
            ),
      onChanged: identities.isEmpty
          ? null
          : (id) {
              if (id != value) onChanged(id);
            },
    ),
  );
}
