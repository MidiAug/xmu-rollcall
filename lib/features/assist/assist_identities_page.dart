import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/features/assist/assist_dialogs.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_identity_card.dart';

class AssistIdentitiesPage extends ConsumerWidget {
  const AssistIdentitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assist = ref.watch(assistControllerProvider);

    return SubpageScaffold(
      title: '协助身份',
      body: AppPageViewport(
        builder: (context, contentInsets) => assist.identities.isEmpty
            ? EmptyHint(
                icon: Icons.person_add_alt_1_outlined,
                title: '还没有协助对象',
                action: AppButton(
                  label: '导入协助身份',
                  onPressed: () => showAssistRosterImport(context, ref),
                ),
              )
            : ListView(
                padding:
                    contentInsets +
                    EdgeInsets.fromLTRB(
                      AppSpace.pageXOf(context),
                      AppSpace.sm,
                      AppSpace.pageXOf(context),
                      AppSpace.xl,
                    ),
                children: [
                  SettingsSection(
                    padTop: false,
                    header: '已导入 ${assist.identities.length}',
                    children: [
                      for (final id in assist.identities)
                        AssistIdentityCard(identity: id, grouped: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: AppMobileUi.useTouchChrome(context)
                          ? double.infinity
                          : null,
                      child: AppButton(
                        label: '导入协助身份',
                        onPressed: assist.busy
                            ? null
                            : () => showAssistRosterImport(context, ref),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

Future<void> showAssistRosterImport(
  BuildContext context,
  WidgetRef ref,
) => showAssistImportDialog(
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
);
