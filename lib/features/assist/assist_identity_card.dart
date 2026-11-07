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
import 'package:xmu_rollcall/features/settings/courses_page.dart';

/// The identity and its overflow menu are separate keyboard/pointer targets.
class AssistIdentityCard extends ConsumerStatefulWidget {
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
  ConsumerState<AssistIdentityCard> createState() => _AssistIdentityCardState();
}

class _AssistIdentityCardState extends ConsumerState<AssistIdentityCard> {
  bool _opening = false;
  AssistIdentity get identity => widget.identity;

  Future<void> _openIdentity() async {
    if (_opening) return;
    final target = identity;
    setState(() => _opening = true);
    try {
      final service = await ref.read(assistServiceProvider.future);
      await service.ensureSession(target);
      if (!mounted || identity.userId != target.userId) return;
      ref.read(selectedRollcallAccountProvider.notifier).state = target.userId;
      if (ShellTabScope.maybeOf(context) != null) {
        ShellNavigation.instance.openRollcall();
      } else {
        AppPageRoutes.push(context, const Scaffold(body: RollcallHubPage()));
      }
    } catch (error) {
      if (mounted && identity.userId == target.userId) {
        AppToast.show(context, '无法切换账号：$error', error: true);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final assist = ref.watch(assistControllerProvider);
    final accent = AssistIdentityCard.avatarColor(identity.userId);

    return AppHoverSurface(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: AppHoverSurface(
              key: ValueKey('assist-open-${identity.userId}'),
              outlined: false,
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              // Retain the focused target while connecting. Removing it could
              // send a repeated Enter to the previous window control instead.
              onTap: _openIdentity,
              child: Row(
                children: [
                  _Avatar(
                    initial: AssistIdentityCard.initialOf(identity.displayName),
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
                        Semantics(
                          liveRegion: _opening,
                          child: _KindBadge(
                            label: _opening ? '正在连接…' : identity.kind.labelZh,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _MoreButton(
              enabled: !assist.busy,
              onSelected: (action) => _onMenuAction(context, ref, action),
            ),
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
      case _RosterAction.timetable:
        await AppPageRoutes.push(
          context,
          CoursesPage(
            assistUserId: identity.userId,
            accountName: identity.displayName,
          ),
        );
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

enum _RosterAction { timetable, viewCourses, refreshCourses, remove }

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.enabled, required this.onSelected});

  final bool enabled;
  final ValueChanged<_RosterAction> onSelected;

  @override
  Widget build(BuildContext context) => AppIconButton(
    tooltip: '更多',
    extent: 34,
    icon: const Icon(AppIcons.more, size: 20),
    onPressed: enabled
        ? () async {
            final action = await _showAssistRosterMenu(context);
            if (action != null) onSelected(action);
          }
        : null,
  );
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
    elevation: AppMenuStyle.elevation,
    color: p.surface,
    surfaceTintColor: Colors.transparent,
    shadowColor: AppMenuStyle.shadow(buttonContext),
    constraints: const BoxConstraints(minWidth: menuWidth, maxWidth: menuWidth),
    shape: AppMenuStyle.shape(buttonContext),
    menuPadding: const EdgeInsets.symmetric(vertical: AppMenuStyle.inset),
    items: [
      AppPopupMenuItem<_RosterAction>(
        value: _RosterAction.timetable,
        icon: AppIcons.week,
        label: '查看课表',
      ),
      AppPopupMenuItem<_RosterAction>(
        value: _RosterAction.viewCourses,
        icon: AppIcons.homework,
        label: '查看同课',
      ),
      AppPopupMenuItem<_RosterAction>(
        value: _RosterAction.refreshCourses,
        icon: AppIcons.refresh,
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
      AppPopupMenuItem<_RosterAction>(
        value: _RosterAction.remove,
        icon: AppIcons.remove,
        label: '删除',
        danger: true,
      ),
    ],
  );
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
