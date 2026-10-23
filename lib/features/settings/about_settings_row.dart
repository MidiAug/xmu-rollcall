import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/settings/about_page.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';

class AboutSettingsRow extends ConsumerWidget {
  const AboutSettingsRow({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(
      appUpdateControllerProvider.select((c) => c.update?.version.name),
    );
    final p = AppPalette.of(context);
    return SettingsRow(
      leading: const Icon(Icons.info_outline_rounded),
      title: '关于',
      subtitle: '版本与应用信息',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (version != null) ...[
            Semantics(
              label: '发现新版本 $version',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: p.selected,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '有更新',
                  style: TextStyle(
                    color: p.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(Icons.chevron_right, color: p.muted, size: 18),
        ],
      ),
      onTap: () => AppPageRoutes.push(context, const AboutPage()),
    );
  }
}
