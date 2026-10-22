import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/app/shell_navigation.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_hub_page.dart';
import 'package:xmu_rollcall/features/assist/assist_shared_course_chip.dart';

/// Assist roster person card — whole card opens the rollcall hub.
class AssistIdentityCard extends ConsumerWidget {
  const AssistIdentityCard({super.key, required this.identity});

  final AssistIdentity identity;

  static const _avatarPalette = <Color>[
    Color(0xFF3D5AFE),
    Color(0xFF4F46E5),
    Color(0xFF0D9488),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFF4338CA),
    Color(0xFF0F766E),
  ];

  static Color avatarColor(int userId) =>
      _avatarPalette[userId.abs() % _avatarPalette.length];

  static String initialOf(String name) {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return String.fromCharCodes(t.runes.take(1));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppPalette.of(context);
    final assist = ref.watch(assistControllerProvider);
    final accent = avatarColor(identity.userId);

    return AppHoverSurface(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                try {
                  final service = await ref.read(assistServiceProvider.future);
                  await service.ensureSession(identity);
                  if (!context.mounted) return;
                  ref.read(selectedRollcallAccountProvider.notifier).state =
                      identity.userId;
                  if (ShellTabScope.maybeOf(context) != null) {
                    ShellNavigation.instance.openRollcall();
                  } else {
                    AppPageRoutes.push(
                      context,
                      const Scaffold(body: RollcallHubPage()),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    AppToast.show(context, '无法切换账号：$error', error: true);
                  }
                }
              },
              child: Row(
                children: [
                  _Avatar(
                    initial: initialOf(identity.displayName),
                    color: accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          identity.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            height: 1.2,
                            color: p.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _KindBadge(label: identity.kind.labelZh),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _MoreButton(
            enabled: !assist.busy,
            onSelected: (action) => _onMenuAction(context, ref, action),
          ),
        ],
      ),
    );
  }

  Future<void> _onMenuAction(
    BuildContext context,
    WidgetRef ref,
    _RosterAction action,
  ) async {
    switch (action) {
      case _RosterAction.viewCourses:
        await showAssistSharedCoursesSheet(
          context,
          identity: identity,
          ref: ref,
        );
      case _RosterAction.refreshCourses:
        try {
          final updated = await ref
              .read(assistControllerProvider.notifier)
              .refreshSharedCourses(identity.userId);
          if (context.mounted) {
            AppToast.show(context, '同课 ${updated.sharedCourses.length} 门');
          }
        } catch (e) {
          if (context.mounted) {
            AppToast.show(context, '$e', error: true);
          }
        }
      case _RosterAction.remove:
        final ok = await showAppConfirmDialog(
          context,
          title: '移除协助账号',
          message:
              '移除「${identity.displayName}」并清除其本地登录信息'
              '${identity.kind == AssistCredentialKind.account ? '与保存的密码' : ''}？',
          confirmLabel: '移除',
          destructive: true,
        );
        if (!ok) return;
        await ref
            .read(assistControllerProvider.notifier)
            .removeIdentity(identity.userId);
    }
  }
}

enum _RosterAction { viewCourses, refreshCourses, remove }

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.enabled, required this.onSelected});

  final bool enabled;
  final ValueChanged<_RosterAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Tooltip(
      message: '更多',
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled
              ? () async {
                  final action = await _showAssistRosterMenu(context);
                  if (action != null) onSelected(action);
                }
              : null,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              Icons.more_horiz_rounded,
              size: 20,
              color: enabled ? p.muted : p.muted.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded floating action menu for an assist roster card.
Future<_RosterAction?> _showAssistRosterMenu(BuildContext buttonContext) {
  final p = AppPalette.of(buttonContext);
  final box = buttonContext.findRenderObject()! as RenderBox;
  final overlay =
      Overlay.of(buttonContext).context.findRenderObject()! as RenderBox;
  final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
  const menuWidth = 196.0;
  final left = (origin.dx + box.size.width - menuWidth).clamp(
    12.0,
    overlay.size.width - menuWidth - 12,
  );
  final position = RelativeRect.fromLTRB(
    left,
    origin.dy + box.size.height + 6,
    overlay.size.width - left - menuWidth,
    0,
  );

  return showMenu<_RosterAction>(
    context: buttonContext,
    position: position,
    elevation: 10,
    color: p.surface,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withValues(alpha: 0.16),
    constraints: const BoxConstraints(minWidth: menuWidth, maxWidth: menuWidth),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: p.borderStrong),
    ),
    menuPadding: const EdgeInsets.all(6),
    items: [
      _RosterMenuItem(
        value: _RosterAction.viewCourses,
        icon: Icons.menu_book_outlined,
        label: '查看同课',
      ),
      _RosterMenuItem(
        value: _RosterAction.refreshCourses,
        icon: Icons.sync_rounded,
        label: '刷新同课',
      ),
      PopupMenuItem<_RosterAction>(
        enabled: false,
        height: 13,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Divider(height: 1, thickness: 1, color: p.border),
        ),
      ),
      _RosterMenuItem(
        value: _RosterAction.remove,
        icon: Icons.delete_outline_rounded,
        label: '删除',
        danger: true,
      ),
    ],
  );
}

class _RosterMenuItem extends PopupMenuItem<_RosterAction> {
  _RosterMenuItem({
    required _RosterAction value,
    required IconData icon,
    required String label,
    bool danger = false,
  }) : super(
         value: value,
         height: 44,
         padding: EdgeInsets.zero,
         child: _RosterMenuRow(icon: icon, label: label, danger: danger),
       );
}

class _RosterMenuRow extends StatelessWidget {
  const _RosterMenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fg = danger ? p.danger : p.ink;
    final iconBg = danger
        ? p.danger.withValues(alpha: 0.12)
        : p.surfaceHigh.withValues(alpha: 0.9);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.15,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: p.surfaceHigh.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
          height: 1.2,
          color: p.muted,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.color});

  final String initial;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.92),
            color.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}
