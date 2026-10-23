import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';

/// Compact status pill for assist roster (方案 A).
class AssistSharedCourseChip extends StatelessWidget {
  const AssistSharedCourseChip({super.key, required this.identity, this.onTap});

  final AssistIdentity identity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final status = identity.sharedCourseStatus;
    final (label, fg, bg) = switch (status) {
      AssistSharedCourseStatus.neverSynced => ('未同步', p.muted, p.surfaceHigh),
      AssistSharedCourseStatus.none => () {
        final warn = Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFFBBF24)
            : const Color(0xFFB45309);
        return ('无同课', warn, warn.withValues(alpha: 0.12));
      }(),
      AssistSharedCourseStatus.some => (
        '同课 ${identity.sharedCourses.length}',
        p.primary,
        p.selected,
      ),
    };

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.control),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showAssistSharedCoursesSheet(
  BuildContext context, {
  required AssistIdentity identity,
  required WidgetRef ref,
}) {
  final p = AppPalette.of(context);
  final status = identity.sharedCourseStatus;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: p.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadii.dialog),
      ),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.xs,
            AppSpace.lg,
            AppSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                identity.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(switch (status) {
                AssistSharedCourseStatus.neverSynced =>
                  '尚未同步与你的共同课程。刷新后才能判断能否在二维码页代签。',
                AssistSharedCourseStatus.none =>
                  '当前没有共同课程，二维码协助勾选中不会出现此人；仍可从其签到页代做数字/雷达。',
                AssistSharedCourseStatus.some => '以下课程与你相同，二维码签到时可勾选代交：',
              }, style: TextStyle(fontSize: 13, height: 1.45, color: p.muted)),
              if (status == AssistSharedCourseStatus.some) ...[
                const SizedBox(height: AppSpace.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: identity.sharedCourses.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: p.border),
                    itemBuilder: (_, i) {
                      final c = identity.sharedCourses[i];
                      final title = c.title.isNotEmpty ? c.title : '课程 ${c.id}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: p.ink,
                          ),
                        ),
                        subtitle: Text(
                          'ID ${c.id}',
                          style: TextStyle(fontSize: 12, color: p.muted),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.md),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    final updated = await ref
                        .read(assistControllerProvider.notifier)
                        .refreshSharedCourses(identity.userId);
                    if (context.mounted) {
                      AppToast.show(
                        context,
                        '同课 ${updated.sharedCourses.length} 门',
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppToast.show(context, '$e', error: true);
                    }
                  }
                },
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('刷新同课'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
