import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_dialogs.dart';
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
      body: AppContentColumn(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpace.pageXOf(context),
            AppSpace.md,
            AppSpace.pageXOf(context),
            AppSpace.xl,
          ),
          children: [
            SettingsSection(
              padTop: false,
              header: '协助',
              children: [
                SettingsRow(
                  leading: const Icon(Icons.upload_outlined),
                  title: '导出协助码',
                  subtitle: auth.isSignedIn ? '生成后复制给同学' : '请先登录',
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                  onTap: !auth.isSignedIn || assist.busy
                      ? null
                      : () => showAssistExportDialog(
                            context,
                            export: (kind) => ref
                                .read(assistControllerProvider.notifier)
                                .exportOwner(kind: kind),
                          ),
                ),
                SettingsRow(
                  leading: const Icon(Icons.download_outlined),
                  title: '导入协助身份',
                  subtitle: '粘贴协助码或输入学号密码',
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                  onTap: assist.busy
                      ? null
                      : () => showAssistImportDialog(
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
                                  .importPlainAccount(
                                    username: user,
                                    password: pass,
                                  );
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
                  leading: const Icon(Icons.group_outlined),
                  title: '已导入名单',
                  subtitle: assist.ready ? '${assist.identities.length} 人' : '…',
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                  onTap: () => AppPageRoutes.push(
                    context,
                    const AssistIdentitiesPage(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
