import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/cache/session_lifecycle.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/radar_preview.dart';
import 'package:xmu_rollcall/features/rollcall/session_prior_preview.dart';
import 'package:xmu_rollcall/features/settings/recent_logs_page.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';
import 'package:xmu_rollcall/platform/shell_debug_preview.dart';

/// 我的 → 数据与诊断。
class SettingsDataPage extends ConsumerWidget {
  const SettingsDataPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceFuture = ref.watch(deviceIdentityProvider).getId();
    final p = AppPalette.of(context);

    return SubpageScaffold(
      title: '数据与诊断',
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
              header: '本机数据',
              children: [
                SettingsRow(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: '清除本机课程数据',
                  subtitle: '清除已保存的课表、作业与签到记录；主题、常用地点与本机标识会保留',
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                  onTap: () => _confirmClearCache(context, ref),
                ),
              ],
            ),
            SettingsSection(
              header: '诊断',
              children: [
                FutureBuilder<String>(
                  future: deviceFuture,
                  builder: (context, snap) {
                    return SettingsRow(
                      leading: const Icon(Icons.devices_outlined),
                      title: '本机标识',
                      subtitleWidget: snap.data == null
                          ? Text(
                              '…',
                              style: TextStyle(color: p.muted, fontSize: 12),
                            )
                          : SelectableText(
                              snap.data!,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                letterSpacing: -0.2,
                                color: p.muted,
                                fontFamily: 'Consolas',
                                fontFamilyFallback: const [
                                  'Menlo',
                                  'monospace',
                                ],
                              ),
                            ),
                      subtitle: '用于识别本机，重装应用前一般保持不变',
                    );
                  },
                ),
                SettingsRow(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: '最近日志',
                  subtitle: '本机诊断事件，可按关键词搜索',
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                  onTap: () =>
                      AppPageRoutes.push(context, const RecentLogsPage()),
                ),
                SettingsRow(
                  leading: const Icon(Icons.ios_share_outlined),
                  title: '导出诊断日志',
                  subtitle: '打包后用系统分享，便于排查问题',
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                  onTap: () async {
                    try {
                      final result = await AppLog.exportLogs(share: true);
                      if (!context.mounted) return;
                      if (result == null) {
                        AppToast.show(context, '暂无日志可导出', error: true);
                      } else {
                        AppToast.show(context, '已打开系统分享');
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      AppToast.show(context, '导出失败：$e', error: true);
                    }
                  },
                ),
              ],
            ),
            if (kDebugMode)
              SettingsSection(
                header: '开发预览',
                children: [
                  SettingsRow(
                    leading: const Icon(Icons.radar_outlined),
                    title: '雷达签到 · 空态',
                    subtitle: '无本课记忆，确认卡为空',
                    trailing:
                        Icon(Icons.chevron_right, color: p.muted, size: 18),
                    onTap: () => openRadarPreview(
                      context,
                      ref,
                      RadarPreviewScenario.empty,
                    ),
                  ),
                  SettingsRow(
                    leading: const Icon(Icons.bookmark_outline),
                    title: '雷达签到 · 记忆预设',
                    subtitle: '预填「翔安教学楼」',
                    trailing:
                        Icon(Icons.chevron_right, color: p.muted, size: 18),
                    onTap: () => openRadarPreview(
                      context,
                      ref,
                      RadarPreviewScenario.prefPlace,
                    ),
                  ),
                  SettingsRow(
                    leading: const Icon(Icons.my_location_outlined),
                    title: '雷达签到 · 记忆定位',
                    subtitle: '预填系统定位坐标',
                    trailing:
                        Icon(Icons.chevron_right, color: p.muted, size: 18),
                    onTap: () => openRadarPreview(
                      context,
                      ref,
                      RadarPreviewScenario.prefDevice,
                    ),
                  ),
                  SettingsRow(
                    leading: const Icon(Icons.insights_outlined),
                    title: '上课段先验',
                    subtitle: '符合 / 突然数字 / 样本不足 / 无课表',
                    trailing:
                        Icon(Icons.chevron_right, color: p.muted, size: 18),
                    onTap: () => openSessionPriorPreview(context),
                  ),
                  if (PlatformHooks.isDesktop || PlatformHooks.isAndroid) ...[
                    SettingsRow(
                      leading: const Icon(Icons.notifications_outlined),
                      title: PlatformHooks.isDesktop
                          ? '托盘 · 立即测试通知'
                          : 'Android · 立即测试发现通知',
                      subtitle: PlatformHooks.isDesktop
                          ? '最小化后发一条发现通知（L1）'
                          : '前台按设计可能不弹；优先用下方 L2',
                      trailing:
                          Icon(Icons.chevron_right, color: p.muted, size: 18),
                      onTap: () => ShellDebugPreview.notifyNow(context),
                    ),
                    SettingsRow(
                      leading: const Icon(Icons.timer_outlined),
                      title: PlatformHooks.isDesktop
                          ? '托盘 · 10s 模拟发现'
                          : 'Android · 10s 模拟发现',
                      subtitle: '假列表 + 停检测 + 通知（L2）',
                      trailing:
                          Icon(Icons.chevron_right, color: p.muted, size: 18),
                      onTap: () => ShellDebugPreview.scheduleDiscovery(
                        context,
                        ref,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearCache(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除本机课程数据？'),
        content: const Text(
          '将删除已保存的课表、作业与签到记录。'
          '主题、常用地点与本机标识会保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await JsonDiskCache.clearAll();
    invalidateOwnerRemoteMemoryFromWidget(ref);
    if (!context.mounted) return;
    AppToast.show(context, '已清除本机课程数据');
  }
}
