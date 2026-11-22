import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_settings_glyph.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_service_symbol.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_dialogs.dart';
import 'package:xmu_rollcall/features/assist/assist_identities_page.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';

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
              dividerIndent:
                  AppDensity.rowPadding(context).left +
                  32 +
                  AppDensity.settingsInnerGap,
              children: [
                SettingsRow(
                  leading: const AppServiceSymbol(
                    size: 32,
                    child: AppSettingsGlyph(
                      AppSettingsGlyphKind.link,
                      size: 16,
                    ),
                  ),
                  leadingSize: 32,
                  title: '导出协助码',
                  subtitle: auth.isSignedIn ? '将协助码发给信任的人' : '请先登录',
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
                  leading: const AppServiceSymbol(
                    size: 32,
                    child: AppSettingsGlyph(
                      AppSettingsGlyphKind.trayDown,
                      size: 16,
                    ),
                  ),
                  leadingSize: 32,
                  title: '导入协助身份',
                  subtitle: '使用协助码或学号密码',
                  trailing: Icon(AppIcons.right, color: p.muted, size: 18),
                  enabled: !assist.busy,
                  onTap: () => showAssistRosterImport(context, ref),
                ),
                SettingsRow(
                  leading: const AppServiceSymbol(
                    size: 32,
                    child: AppSettingsGlyph(
                      AppSettingsGlyphKind.user,
                      size: 16,
                    ),
                  ),
                  leadingSize: 32,
                  title: '已导入名单',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        assist.ready ? '${assist.identities.length} 人' : '…',
                        style: AppTypography.control.copyWith(color: p.muted),
                      ),
                      const SizedBox(width: 8),
                      const Icon(AppIcons.right, size: 18),
                    ],
                  ),
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
