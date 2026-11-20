import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_dialogs.dart';
import 'package:xmu_rollcall/features/assist/assist_identities_page.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';

/// 我的 → 协助同学（导出 / 导入 / 名单）。
class SettingsAssistPage extends ConsumerWidget {
  const SettingsAssistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final assist = ref.watch(assistControllerProvider);
    final p = AppPalette.of(context);

    return SubpageScaffold(
      title: '协助同学',
      body: AppPageViewport(
        builder: (context, contentInsets) => ListView(
          padding:
              contentInsets +
              EdgeInsets.fromLTRB(
                AppSpace.pageXOf(context),
                AppSpace.md,
                AppSpace.pageXOf(context),
                AppSpace.xl,
              ),
          children: [
            SettingsSection(
              padTop: false,
              children: [
                SettingsRow(
                  leading: const Icon(AppIcons.upload),
                  title: '导出协助码',
                  subtitle: auth.isSignedIn ? null : '请先登录',
                  trailing: Icon(AppIcons.right, color: p.muted, size: 18),
                  enabled: auth.isSignedIn && !assist.busy,
                  onTap: () => showAssistExportDialog(
                    context,
                    export: (kind) => ref
                        .read(assistControllerProvider.notifier)
                        .exportOwner(kind: kind),
                  ),
                ),
                SettingsRow(
                  leading: const Icon(AppIcons.download),
                  title: '导入协助身份',
                  trailing: Icon(AppIcons.right, color: p.muted, size: 18),
                  enabled: !assist.busy,
                  onTap: () => showAssistImportDialog(
                    context,
                    onImportToken: (token) async {
                      final id = await ref
                          .read(assistControllerProvider.notifier)
                          .importToken(token);
                      if (context.mounted) {
                        AppToast.show(
                          context,
                          '已导入 ${id.displayName}（${id.kind.labelZh}，同课 ${id.sharedCourses.length} 门）',
                        );
                      }
                    },
                    onImportPlain: (user, pass) async {
                      final id = await ref
                          .read(assistControllerProvider.notifier)
                          .importPlainAccount(username: user, password: pass);
                      if (context.mounted) {
                        AppToast.show(
                          context,
                          '已导入 ${id.displayName}（${id.kind.labelZh}，同课 ${id.sharedCourses.length} 门）',
                        );
                      }
                    },
                  ),
                ),
                SettingsRow(
                  leading: const Icon(AppIcons.people),
                  title: '已导入名单',
                  subtitle: assist.ready
                      ? '${assist.identities.length} 人'
                      : '…',
                  trailing: Icon(AppIcons.right, color: p.muted, size: 18),
                  onTap: () =>
                      AppPageRoutes.push(context, const AssistIdentitiesPage()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
