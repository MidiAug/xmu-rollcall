import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_settings_glyph.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/browser/campus_website.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'logistics_provider.dart';

Uri logisticsWebsite(String path) =>
    Uri.https('xdhq.xmu.edu.cn', '/ihome/$path');

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
    Future<void> official(String path, String title) =>
        openCampusWebsite(context, title: title, url: logisticsWebsite(path));
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
                        onPressed: () => official('repairCatalogue', '我要报修'),
                      ),
                      AppButton(
                        label: '意见反馈',
                        kind: AppButtonKind.secondary,
                        onPressed: () => official('service/catalogue', '意见反馈'),
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
                              AppButton(
                                label: '打开官方报修',
                                kind: AppButtonKind.quiet,
                                onPressed: () =>
                                    official('myRepairList', '我的报修'),
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
                        onTap: () => official('messageList', '后勤消息'),
                      ),
                      SettingsRow(
                        title: '我的反馈',
                        leading: const AppSettingsGlyph(
                          AppSettingsGlyphKind.fileText,
                        ),
                        trailing: const Icon(AppIcons.right, size: 14),
                        onTap: () => official('service/myService', '我的反馈'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class LogisticsRepairPage extends ConsumerWidget {
  const LogisticsRepairPage({super.key, required this.repair});
  final LogisticsRepair repair;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A detail opened for one identity must never remain visible after switching.
    ref.listen(browserIdentityProvider, (previous, next) {
      if (previous == next) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      });
    });
    return SubpageScaffold(
      title: '报修详情',
      body: AppPageViewport(
        maxWidth: AppLayout.workspaceMaxWidth,
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
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
                SettingsRow(title: '报修单号', subtitle: repair.number),
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
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: repair.completed && !repair.evaluated
                    ? '前往官方页面评价'
                    : '打开官方报修',
                kind: AppButtonKind.secondary,
                onPressed: () => openCampusWebsite(
                  context,
                  title: '我的报修',
                  url: logisticsWebsite('myRepairList'),
                ),
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
