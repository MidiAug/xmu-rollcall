import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_identity_card.dart';

class AssistIdentitiesPage extends ConsumerWidget {
  const AssistIdentitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assist = ref.watch(assistControllerProvider);
    final p = AppPalette.of(context);

    return SubpageScaffold(
      title: '协助身份',
      body: AppPageViewport(
        builder: (context, contentInsets) => assist.identities.isEmpty
            ? EmptyHint(
                icon: Icons.person_add_alt_1_outlined,
                title: '还没有协助对象',
                detail: '请先导入协助身份，再点姓名进入其签到页。',
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.xs,
                      0,
                      AppSpace.xs,
                      AppSpace.xs,
                    ),
                    child: Text(
                      '已导入 ${assist.identities.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.muted,
                      ),
                    ),
                  ),
                  for (final id in assist.identities)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xs),
                      child: AssistIdentityCard(identity: id),
                    ),
                ],
              ),
      ),
    );
  }
}
