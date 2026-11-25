import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_settings_glyph.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'logistics_provider.dart';
import 'logistics_forms.dart';
import 'logistics_records.dart';
import 'logistics_form_widgets.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';

class LogisticsPage extends ConsumerWidget {
  const LogisticsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(browserIdentityProvider);
    final name = ref.watch(rollcallAccountNameProvider);
    final data = identity.userId == null ? null : ref.watch(logisticsProvider);
    final notifier = identity.userId == null
        ? null
        : ref.read(logisticsProvider.notifier);
    Future<void> form(Widget page) async {
      final changed = await AppPageRoutes.push<bool>(context, page);
      if (context.mounted && changed == true) {
        await ref.read(logisticsProvider.notifier).afterMutation();
      }
    }

    final p = AppPalette.of(context);
    return SubpageScaffold(
      title: '智慧后勤',
      actions: [
        if (notifier != null)
          AppRefreshButton(
            tooltip: '更新报修与消息',
            busy: notifier.updating,
            onRefresh: () => notifier.refresh(),
          ),
      ],
      body: identity.userId == null
          ? const EmptyHint(
              icon: AppIcons.person,
              title: '请先登录',
              detail: '查看本人的报修与后勤消息',
            )
          : AppPageViewport(
              maxWidth: AppLayout.workspaceMaxWidth,
              builder: (context, insets) => ListView(
                padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpace.md),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      AppButton(
                        label: '我要报修',
                        icon: AppIcons.add,
                        onPressed: () => form(const LogisticsRepairForm()),
                      ),
                      AppButton(
                        label: '意见反馈',
                        kind: AppButtonKind.secondary,
                        onPressed: () => form(const LogisticsFeedbackForm()),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.lg),
                  data!.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpace.xl),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('暂时无法读取后勤数据'),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            error is FormatException
                                ? error.message
                                : '请稍后重试，或重新登录所选账号',
                            style: TextStyle(color: p.muted),
                          ),
                          const SizedBox(height: AppSpace.md),
                          Wrap(
                            spacing: AppSpace.sm,
                            runSpacing: AppSpace.sm,
                            children: [
                              AppButton(
                                label: '重试',
                                kind: AppButtonKind.secondary,
                                onPressed: () => notifier!.refresh(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    data: (snapshot) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (notifier!.warning != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.md),
                            child: Text(
                              '${notifier.warning}，显示上次读取的数据',
                              style: TextStyle(color: p.muted),
                            ),
                          ),
                        Text(
                          '更新于 ${_date(snapshot.fetchedAt)}',
                          style: AppTypography.caption.copyWith(color: p.muted),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        SettingsSection(
                          header: '我的报修',
                          padTop: false,
                          hasLeading: false,
                          children: [
                            if (snapshot.repairs.isEmpty)
                              const SettingsRow(title: '暂无报修记录'),
                            for (final repair in snapshot.repairs)
                              SettingsRow(
                                key: ValueKey('repair-${repair.id}'),
                                title: repair.project,
                                subtitleWidget: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      repair.content,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: AppSpace.xs),
                                    Text(
                                      repair.area,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                        color: p.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      repair.status,
                                      style: AppTypography.caption.copyWith(
                                        color: p.muted,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpace.xs),
                                    const Icon(AppIcons.right, size: 14),
                                  ],
                                ),
                                onTap: () => AppPageRoutes.push(
                                  context,
                                  LogisticsRepairPage(repair: repair),
                                ),
                              ),
                          ],
                        ),
                        if (snapshot.repairs.length < snapshot.total)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.sm),
                            child: Align(
                              alignment: Alignment.center,
                              child: AppButton(
                                label: '加载更多报修',
                                kind: AppButtonKind.quiet,
                                busy: notifier.updating,
                                onPressed: () => notifier.refresh(more: true),
                              ),
                            ),
                          ),
                        SettingsSection(
                          header: '最近消息',
                          hasLeading: false,
                          children: [
                            if (snapshot.messages.isEmpty)
                              const SettingsRow(title: '暂无后勤消息'),
                            for (final message in snapshot.messages)
                              SettingsRow(
                                title: message.title,
                                subtitleWidget: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(message.content),
                                    const SizedBox(height: AppSpace.xs),
                                    Text(
                                      message.time,
                                      style: AppTypography.caption.copyWith(
                                        color: p.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: message.unread
                                    ? const Text('未读')
                                    : null,
                                onTap: () => AppPageRoutes.push<void>(
                                  context,
                                  LogisticsMessagePage(message: message),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SettingsSection(
                    hasLeading: true,
                    children: [
                      SettingsRow(
                        title: '全部消息',
                        leading: const AppSettingsGlyph(
                          AppSettingsGlyphKind.bell,
                        ),
                        trailing: const Icon(AppIcons.right, size: 14),
                        onTap: () => AppPageRoutes.push<void>(
                          context,
                          const LogisticsMessagesPage(),
                        ),
                      ),
                      SettingsRow(
                        title: '我的反馈',
                        leading: const AppSettingsGlyph(
                          AppSettingsGlyphKind.fileText,
                        ),
                        trailing: const Icon(AppIcons.right, size: 14),
                        onTap: () => AppPageRoutes.push<void>(
                          context,
                          const LogisticsFeedbackPage(),
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

class LogisticsRepairPage extends ConsumerStatefulWidget {
  const LogisticsRepairPage({super.key, required this.repair});
  final LogisticsRepair repair;
  @override
  ConsumerState<LogisticsRepairPage> createState() =>
      _LogisticsRepairPageState();
}

class _LogisticsRepairPageState extends ConsumerState<LogisticsRepairPage>
    with LogisticsIdentityPage<LogisticsRepairPage> {
  Map<String, dynamic>? detail;
  LogisticsRepair? latest;
  bool withdrawable = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() => perform(() async {
    final data = await ref
        .read(logisticsProvider.notifier)
        .run(
          (c) async => (
            detail: await c.repairDetail(widget.repair.id),
            canWithdraw: await c.canWithdraw(widget.repair.id),
          ),
        );
    final parsed = LogisticsRepair({
      ...data.detail,
      'logs': data.detail['logVOS'] ?? [],
      'workerName':
          ((data.detail['finishedInfo'] as Map?)?['workerList'] as List? ?? [])
              .map((w) => w['workerName'])
              .join('、'),
      'repairDeptName':
          data.detail['acceptDeptName'] ?? data.detail['repairDeptName'],
    });
    if (current) {
      detail = data.detail;
      latest = parsed;
      withdrawable = data.canWithdraw;
    }
  });
  @override
  Widget build(BuildContext context) {
    watchIdentity();
    final repair = latest ?? widget.repair;
    final finished = detail?['finishedInfo'] as Map?;
    final images = [
      for (final item in detail?['resourcesVOS'] as List? ?? [])
        if (item is Map && item['fileUrl'] is String) item['fileUrl'] as String,
    ];
    return SubpageScaffold(
      title: '报修详情',
      isBusy: () => busy,
      actions: [AppRefreshButton(busy: busy, onRefresh: load)],
      body: AppPageViewport(
        maxWidth: AppLayout.workspaceMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.md),
                child: Text(error!),
              ),
            SettingsSection(
              padTop: false,
              hasLeading: false,
              children: [
                SettingsRow(title: repair.project, subtitle: repair.status),
                SettingsRow(title: '故障描述', subtitle: repair.content),
                SettingsRow(
                  title: '故障地点',
                  subtitle: '${repair.area}\n${repair.address}',
                ),
                if (repair.department.isNotEmpty)
                  SettingsRow(title: '服务单位', subtitle: repair.department),
                if (repair.worker.isNotEmpty)
                  SettingsRow(title: '维修人员', subtitle: repair.worker),
                if (finished?['paymentTypeName'] is String)
                  SettingsRow(
                    title: '收费类型',
                    subtitle: finished!['paymentTypeName'] as String,
                  ),
                if (finished?['totalCost'] is num &&
                    (finished!['totalCost'] as num) > 0)
                  SettingsRow(
                    title: '维修费用',
                    subtitle: '${finished['totalCost']}元',
                  ),
                SettingsRow(title: '报修单号', subtitle: repair.number),
              ],
            ),
            if (images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.md),
                child: LogisticsImages(paths: images),
              ),
            for (final kind in ['beforeImg', 'afterImg'])
              if (finished?[kind] is String &&
                  (finished![kind] as String).isNotEmpty)
                SettingsSection(
                  header: kind == 'beforeImg' ? '维修前' : '维修后',
                  hasLeading: false,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: LogisticsImages(
                        paths: (finished[kind] as String).split(','),
                      ),
                    ),
                  ],
                ),
            SettingsSection(
              header: '工单进度',
              hasLeading: false,
              children: [
                if (repair.logs.isEmpty) const SettingsRow(title: '暂无进度记录'),
                for (final log in repair.logs)
                  SettingsRow(
                    title: log.title,
                    subtitle: log.time,
                    subtitleWidget: log.content.isEmpty
                        ? null
                        : Text(log.content),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            if (repair.completed && !repair.evaluated)
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: '评价维修',
                  onPressed: busy
                      ? null
                      : () async {
                          final changed = await AppPageRoutes.push<bool>(
                            context,
                            LogisticsEvaluationPage(repairId: repair.id),
                          );
                          if (current && changed == true) {
                            await ref
                                .read(logisticsProvider.notifier)
                                .afterMutation();
                            await load();
                          }
                        },
                ),
              ),
            if (withdrawable)
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: '撤销报修',
                  kind: AppButtonKind.secondary,
                  busy: busy,
                  onPressed: () async {
                    final ok = await showAppConfirmDialog(
                      context,
                      title: '撤销这条报修？',
                      message: '撤销后服务部门将不再按此单继续处理。',
                      confirmLabel: '撤销报修',
                      destructive: true,
                    );
                    if (!current || !ok) return;
                    await perform(() async {
                      await ref
                          .read(logisticsProvider.notifier)
                          .run((c) => c.withdraw(repair.id));
                      if (current) {
                        await ref
                            .read(logisticsProvider.notifier)
                            .afterMutation();
                      }
                    });
                    if (current) await load();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
