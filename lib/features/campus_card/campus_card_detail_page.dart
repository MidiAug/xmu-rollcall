import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'campus_card_providers.dart';
import 'campus_card_page_session.dart';

class CampusCardDetailPage extends ConsumerStatefulWidget {
  const CampusCardDetailPage({super.key});
  @override
  ConsumerState<CampusCardDetailPage> createState() =>
      _CampusCardDetailPageState();
}

class _CampusCardDetailPageState extends ConsumerState<CampusCardDetailPage>
    with CampusCardPageSession<CampusCardDetailPage> {
  List<({String name, double balance})> accounts = [];
  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() => perform(() async {
    final data = await ref
        .read(campusCardInfoProvider.notifier)
        .run((c) => c.accounts());
    if (current) accounts = data;
  });
  @override
  Widget build(BuildContext context) {
    watchSession();
    final snapshot = ref.watch(campusCardInfoProvider);
    final info = snapshot.isReloading ? null : snapshot.valueOrNull;
    return SubpageScaffold(
      title: '卡片详情',
      actions: [AppRefreshButton(busy: busy, onRefresh: load)],
      body: AppPageViewport(
        maxWidth: AppLayout.readingMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (info != null)
              SettingsSection(
                padTop: false,
                hasLeading: false,
                children: [
                  SettingsRow(title: '卡号', subtitle: info.account),
                  if (info.cardName.isNotEmpty)
                    SettingsRow(title: '卡片类型', subtitle: info.cardName),
                  SettingsRow(
                    title: '挂失状态',
                    subtitle: info.lost ? '已挂失' : '未挂失',
                  ),
                  if (info.frozen)
                    const SettingsRow(title: '冻结状态', subtitle: '已冻结'),
                  if (info.expiryDate.isNotEmpty)
                    SettingsRow(
                      title: '有效期',
                      subtitle: cardDate(info.expiryDate),
                    ),
                  if (info.createdDate.isNotEmpty)
                    SettingsRow(
                      title: '开卡日期',
                      subtitle: cardDate(info.createdDate),
                    ),
                  if (info.electricityCents != 0)
                    SettingsRow(
                      title: '电费账户余额',
                      trailing: Text(
                        '¥${info.electricityYuan.toStringAsFixed(2)}',
                      ),
                    ),
                ],
              ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(AppSpace.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (error != null) Text(error!),
            if (accounts.isNotEmpty)
              SettingsSection(
                header: '其他账户',
                hasLeading: false,
                children: [
                  for (final row in accounts)
                    SettingsRow(
                      title: row.name,
                      trailing: Text('¥${row.balance.toStringAsFixed(2)}'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
