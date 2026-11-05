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
      triggerBuilder: sidebar
          ? (context, open, toggle, focus) => _SidebarAccountTrigger(
              name: value == 0
                  ? ownerName
                  : identities.firstWhere((e) => e.userId == value).displayName,
              role: value == 0 ? '主账号' : '协助账号',
              watching: watchingAccounts.contains(value),
              open: open,
              focusNode: focus,
              onPressed: toggle,
            )
          : masthead && Theme.of(context).platform == TargetPlatform.android
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
      trailing: !sidebar && watchingAccounts.contains(value)
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
          ? null
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

/// Identity is a two-line unit. Watch status shares the role line so adding it
/// never steals the name's width or forces the role into a third line.
class _SidebarAccountTrigger extends StatelessWidget {
  const _SidebarAccountTrigger({
    required this.name,
    required this.role,
    required this.watching,
    required this.open,
    required this.focusNode,
    required this.onPressed,
  });
  final String name, role;
  final bool watching, open;
  final FocusNode focusNode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return TextButton(
      focusNode: focusNode,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        foregroundColor: p.ink,
        disabledForegroundColor: p.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: p.selected,
            child: Text(
              name.characters.firstOrNull ?? '我',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: p.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTruncatedText(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: p.muted,
                        ),
                      ),
                    ),
                    if (watching) ...[
                      const SizedBox(width: 4),
                      AppTooltipAnchor(
                        child: Tooltip(
                          message: '值守中',
                          child: Icon(
                            AppIcons.guard,
                            size: 12,
                            color: p.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          AnimatedRotation(
            turns: open ? .5 : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppMotion.fast,
            child: Icon(AppIcons.down, size: 12, color: p.muted),
          ),
        ],
      ),
    );
  }
}
