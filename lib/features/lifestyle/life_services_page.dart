import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_settings_glyph.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_detail_page.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_providers.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_records.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_forms.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_power_page.dart';
import 'package:xmu_rollcall/features/campus_card/campus_card_cashier.dart';
import 'package:xmu_rollcall/features/campus_card/electricity_provider.dart';

class LifeServicesPage extends ConsumerWidget {
  const LifeServicesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(browserIdentityProvider);
    final info = identity.userId == null
        ? null
        : ref.watch(campusCardInfoProvider);
    final notifier = identity.userId == null
        ? null
        : ref.read(campusCardInfoProvider.notifier);
    void open(Widget page) => AppPageRoutes.push<void>(context, page);
    final electricity = identity.userId == null
        ? null
        : ref.watch(electricityProvider);
    final personal = electricity?.isReloading == true
        ? null
        : electricity?.valueOrNull?[CardElectricRoomKind.personal];
    final palette = AppPalette.of(context);
    final canPay = campusCardCanPayOn(Theme.of(context).platform);
    return SubpageScaffold(
      title: '生活服务',
      actions: [
        if (notifier != null)
          AppRefreshButton(
            busy: notifier.updating,
            onRefresh: () async {
              await Future.wait([
                notifier.refresh(),
                ref.read(electricityProvider.notifier).refresh(),
              ]);
            },
          ),
      ],
      body: identity.userId == null
          ? const EmptyHint(icon: AppIcons.person, title: '请先登录')
          : AppPageViewport(
              maxWidth: AppLayout.readingMaxWidth,
              builder: (context, insets) => ListView(
                padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
                children: [
                  info!.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('暂时无法读取校园卡'),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            e is FormatException ? e.message : '请检查网络后重试',
                            style: TextStyle(color: palette.muted),
                          ),
                          const SizedBox(height: AppSpace.md),
                          AppButton(
                            label: '重试',
                            onPressed: () => notifier!.refresh(),
                          ),
                        ],
                      ),
                    ),
                    data: (card) => Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '校园卡余额',
                                style: TextStyle(color: palette.muted),
                              ),
                              const Spacer(),
                              if (card.lost)
                                const AppStatusBadge(
                                  '已挂失',
                                  tone: AppStatusTone.danger,
                                ),
                              if (card.frozen)
                                const AppStatusBadge(
                                  '已冻结',
                                  tone: AppStatusTone.warning,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            '¥${card.balanceYuan.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          if (notifier!.fetchedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpace.sm),
                              child: Text(
                                '上次核对 ${notifier.fetchedAt!.toLocal().toString().substring(0, 16)}',
                                style: AppTypography.caption.copyWith(
                                  color: palette.muted,
                                ),
                              ),
                            ),
                          if (card.unsettledCents != 0)
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpace.sm),
                              child: Text(
                                '待领取 ¥${(card.unsettledCents / 100).toStringAsFixed(2)}',
                                style: TextStyle(color: palette.muted),
                              ),
                            ),
                          const SizedBox(height: AppSpace.lg),
                          AppMetric(
                            label: '个人房间电费',
                            value: personal == null
                                ? '—'
                                : '¥${personal.balance.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: AppSpace.lg),
                          AppButton(
                            label: '充值',
                            icon: AppIcons.add,
                            onPressed: canPay
                                ? () => open(const CampusCardPaymentPage())
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!canPay)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.sm),
                      child: Text(
                        '请在手机端充值',
                        style: AppTypography.caption.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ),
                  if (notifier!.warning != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.sm),
                      child: Text(
                        '${notifier.warning}${info.valueOrNull == null ? '' : '，显示上次数据'}',
                        style: TextStyle(color: palette.muted),
                      ),
                    ),
                  SettingsSection(
                    header: '校园卡',
                    children: [
                      SettingsRow(
                        title: '使用记录',
                        leading: const AppSettingsGlyph(
                          AppSettingsGlyphKind.clock,
                        ),
                        trailing: const Icon(AppIcons.right, size: 14),
                        onTap: () => open(
                          const CampusCardRecordsPage(
                            kind: CardRecordKind.transactions,
                          ),
                        ),
                      ),
                      SettingsRow(
                        title: '我的账单',
                        leading: const AppSettingsGlyph(
                          AppSettingsGlyphKind.fileText,
                        ),
                        trailing: const Icon(AppIcons.right, size: 14),
                        onTap: () => open(const CampusCardBillsPage()),
                      ),
                      SettingsRow(
                        title: '免费米饭账单',
                        leading: const AppSettingsGlyph(
                          AppSettingsGlyphKind.fileText,
                        ),
                        trailing: const Icon(AppIcons.right, size: 14),
                        onTap: () => open(
                          const CampusCardRecordsPage(
                            kind: CardRecordKind.rice,
                          ),
                        ),
                      ),
                      SettingsRow(
                        title: '卡片详情',
                        leading: const AppSettingsGlyph(
                          AppSettingsGlyphKind.info,
                        ),
                        trailing: const Icon(AppIcons.right, size: 14),
                        onTap: () => open(const CampusCardDetailPage()),
                      ),
                    ],
                  ),
                  SettingsSection(
                    header: '宿舍',
                    children: [
                      SettingsRow(
                        title: '电费缴费',
                        leading: const AppSettingsGlyph(
                          AppSettingsGlyphKind.power,
                        ),
                        trailing: const Icon(AppIcons.right, size: 14),
                        onTap: () => open(const CampusCardPowerPage()),
                      ),
                    ],
                  ),
                  SettingsSection(
                    header: '账户管理',
                    children: [
                      SettingsRow(
                        title: '修改查询密码',
                        leading: const AppSettingsGlyph(
                          AppSettingsGlyphKind.shieldCheck,
                        ),
                        trailing: const Icon(AppIcons.right, size: 14),
                        onTap: () => open(const CampusCardSecurityPage()),
                      ),
                      SettingsRow(
                        title: '卡片挂失',
                        leading: const AppSettingsGlyph(
                          AppSettingsGlyphKind.shieldCheck,
                        ),
                        trailing: const Icon(AppIcons.right, size: 14),
                        onTap: () =>
                            open(const CampusCardSecurityPage(lost: true)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

/// Directory summaries only restore native cached data; they do not start a
/// second account request just because the tools directory is visible.
class LifeServiceBalancesTrailing extends ConsumerWidget {
  const LifeServiceBalancesTrailing({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(campusCardCachedInfoProvider);
    final card = snapshot.isReloading ? null : snapshot.valueOrNull;
    final electricity = ref.watch(cachedElectricityProvider);
    final personal = electricity.isReloading
        ? null
        : electricity.valueOrNull?[CardElectricRoomKind.personal];
    final style = AppTypography.caption.copyWith(
      color: AppPalette.of(context).muted,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          card == null
              ? '校园卡 —'
              : '上次校园卡 ¥${card.balanceYuan.toStringAsFixed(2)}',
          style: style,
        ),
        Text(
          personal == null
              ? '个人电费 —'
              : '个人电费 ¥${personal.balance.toStringAsFixed(2)}',
          style: style,
        ),
      ],
    );
  }
}
