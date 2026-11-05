import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/app/session_lifecycle.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/radar_preview.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_preview_page.dart';
import 'package:xmu_rollcall/features/rollcall/session_prior_preview.dart';
import 'package:xmu_rollcall/features/settings/recent_logs_page.dart';
import 'package:xmu_rollcall/features/settings/timetable_preview.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';
import 'package:xmu_rollcall/platform/shell_debug_preview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_providers.dart';
import 'package:xmu_rollcall/features/rollcall/desktop_qr_preview.dart';
import 'package:xmu_rollcall/features/update/update_preview_page.dart';

/// 我的 → 数据与诊断。
class SettingsDataPage extends ConsumerWidget {
  const SettingsDataPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceFuture = ref.watch(deviceIdentityProvider).getId();
    final p = AppPalette.of(context);
    final auth = ref.watch(authControllerProvider);
    final scope = ref.watch(selectedRollcallAccountProvider);
    final uid = scope ?? auth.profile?.id;
    final accountName = scope == null
        ? auth.profile?.name ?? '当前账号'
        : ref
                  .watch(assistControllerProvider)
                  .identities
                  .where((identity) => identity.userId == scope)
                  .firstOrNull
                  ?.displayName ??
              '当前协助账号';

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
            if (auth.isSignedIn && uid != null)
              SettingsSection(
                padTop: false,
                header: '数据更新',
                children: [
                  _TimetableRefreshRow(
                    key: ValueKey((auth.profile!.id, uid)),
                    uid: uid,
                    accountName: accountName,
                  ),
                ],
              ),
            SettingsSection(
              padTop: auth.isSignedIn,
              header: '本机数据',
              children: [
                SettingsRow(
                  leading: const Icon(AppIcons.clean),
                  title: '清除本机课程数据',
                  subtitle: '清除已缓存的课表、成绩、作业与签到记录；手工安排、地点与本机设置会保留',
                  trailing: Icon(AppIcons.right, color: p.muted, size: 18),
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
                    final id = snap.data;
                    return SettingsRow(
                      leading: const Icon(AppIcons.devices),
                      title: '本机标识',
                      subtitleWidget: Text(
                        id ?? (snap.hasError ? '暂时无法读取' : '…'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          letterSpacing: -0.2,
                          color: p.muted,
                          fontFamily: 'Consolas',
                          fontFamilyFallback: const ['Menlo', 'monospace'],
                        ),
                      ),
                      trailing: Tooltip(
                        message: '复制本机标识',
                        child: Icon(AppIcons.copy, color: p.muted, size: 18),
                      ),
                      onTap: id == null
                          ? null
                          : () async {
                              try {
                                await Clipboard.setData(
                                  ClipboardData(text: id),
                                );
                                if (context.mounted) {
                                  AppToast.show(context, '已复制本机标识');
                                }
                              } on PlatformException {
                                if (context.mounted) {
                                  AppToast.show(
                                    context,
                                    '复制失败，请重试',
                                    error: true,
                                  );
                                }
                              }
                            },
                    );
                  },
                ),
                SettingsRow(
                  leading: const Icon(AppIcons.document),
                  title: '最近日志',
                  subtitle: '本机诊断事件，可按关键词搜索',
                  trailing: Icon(AppIcons.right, color: p.muted, size: 18),
                  onTap: () =>
                      AppPageRoutes.push(context, const RecentLogsPage()),
                ),
                const _ExportLogsRow(),
              ],
            ),
            if (kDebugMode)
              SettingsSection(
                header: '开发预览',
                children: [
                  SettingsRow(
                    leading: const Icon(AppIcons.radar),
                    title: PlatformHooks.isDesktop ? '电脑端签到与状态' : '签到首页',
                    subtitle: '完整首页、多方式与状态组合，模拟提交',
                    trailing: const Icon(AppIcons.right, size: 18),
                    onTap: () => AppPageRoutes.push(
                      context,
                      RollcallPreviewPage(desktop: PlatformHooks.isDesktop),
                    ),
                  ),
                  SettingsRow(
                    leading: const Icon(AppIcons.download),
                    title: '更新流程',
                    subtitle: '说明、检查、下载、线路与安装确认',
                    trailing: const Icon(AppIcons.right, size: 18),
                    onTap: () =>
                        AppPageRoutes.push(context, UpdatePreviewPage()),
                  ),
                  if (PlatformHooks.isWindows)
                    SettingsRow(
                      leading: const Icon(AppIcons.qr),
                      title: '电脑扫码  透明浮窗',
                      subtitle: '屏幕识别  拖入图片  选择图片，不提交签到',
                      trailing: const Icon(AppIcons.right, size: 18),
                      onTap: () => AppPageRoutes.push(
                        context,
                        const DesktopQrPreviewPage(),
                      ),
                    ),
                  SettingsRow(
                    leading: const Icon(AppIcons.radar),
                    title: '雷达签到  空态',
                    subtitle: '无本课记忆，确认卡为空',
                    trailing: Icon(AppIcons.right, color: p.muted, size: 18),
                    onTap: () => openRadarPreview(
                      context,
                      ref,
                      RadarPreviewScenario.empty,
                    ),
                  ),
                  SettingsRow(
                    leading: const Icon(AppIcons.bookmark),
                    title: '雷达签到  记忆预设',
                    subtitle: '预填「翔安教学楼」',
                    trailing: Icon(AppIcons.right, color: p.muted, size: 18),
                    onTap: () => openRadarPreview(
                      context,
                      ref,
                      RadarPreviewScenario.prefPlace,
                    ),
                  ),
                  SettingsRow(
                    leading: const Icon(AppIcons.location),
                    title: '雷达签到  记忆定位',
                    subtitle: '预填系统定位坐标',
                    trailing: Icon(AppIcons.right, color: p.muted, size: 18),
                    onTap: () => openRadarPreview(
                      context,
                      ref,
                      RadarPreviewScenario.prefDevice,
                    ),
                  ),
                  SettingsRow(
                    leading: const Icon(AppIcons.data),
                    title: '上课段先验',
                    subtitle: '符合 / 突然数字 / 样本不足 / 无课表',
                    trailing: Icon(AppIcons.right, color: p.muted, size: 18),
                    onTap: () => openSessionPriorPreview(context),
                  ),
                  SettingsRow(
                    leading: const Icon(AppIcons.week),
                    title: '课表样式',
                    subtitle: '周末列  有无 10–11 节  假数据',
                    trailing: Icon(AppIcons.right, color: p.muted, size: 18),
                    onTap: () => openTimetablePreview(context),
                  ),
                  if (PlatformHooks.isDesktop || PlatformHooks.isAndroid) ...[
                    SettingsRow(
                      leading: const Icon(AppIcons.notification),
                      title: PlatformHooks.isDesktop
                          ? '托盘  立即测试通知'
                          : 'Android  立即测试发现通知',
                      subtitle: PlatformHooks.isDesktop
                          ? '最小化后发一条发现通知（L1）'
                          : '直接测试声音与震动，不影响正在进行的检测',
                      trailing: Icon(AppIcons.right, color: p.muted, size: 18),
                      onTap: () => ShellDebugPreview.notifyNow(context),
                    ),
                    SettingsRow(
                      leading: const Icon(AppIcons.clock),
                      title: PlatformHooks.isDesktop
                          ? '托盘  10s 模拟发现'
                          : 'Android  30s 模拟发现',
                      subtitle: PlatformHooks.isAndroid
                          ? '由后台服务发送，可回桌或锁屏验证'
                          : '延时测试通知，不修改真实签到列表',
                      trailing: Icon(AppIcons.right, color: p.muted, size: 18),
                      onTap: () => ShellDebugPreview.scheduleDiscovery(
                        context,
                        ref,
                        delay: Duration(
                          seconds: PlatformHooks.isAndroid ? 30 : 10,
                        ),
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
          '将删除已缓存的课表、成绩、作业与签到记录。'
          '手工课程安排、学期日期、地点与本机设置会保留。',
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
    await clearRemoteCourseData(ref);
    if (!context.mounted) return;
    AppToast.show(context, '已清除本机课程数据');
  }
}

class _TimetableRefreshRow extends ConsumerStatefulWidget {
  const _TimetableRefreshRow({
    super.key,
    required this.uid,
    required this.accountName,
  });
  final int uid;
  final String accountName;
  @override
  ConsumerState<_TimetableRefreshRow> createState() =>
      _TimetableRefreshRowState();
}

class _TimetableRefreshRowState extends ConsumerState<_TimetableRefreshRow> {
  bool _busy = false;
  String? _status;
  bool _error = false;

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final before = await ref.read(
        academicCachedScheduleProvider(widget.uid).future,
      );
      if (!mounted) return;
      final sync = ref.read(academicSyncProvider);
      await sync.sync(widget.uid, force: true);
      if (!mounted) return;
      ref.invalidate(academicCachedScheduleProvider(widget.uid));
      ref.invalidate(academicTimetableProvider(widget.uid));
      final after = await ref.read(
        academicCachedScheduleProvider(widget.uid).future,
      );
      if (!mounted) return;
      final error = sync.errorFor(widget.uid);
      setState(() {
        _error = error != null;
        _status =
            error ??
            (after?.fetchedAt == before?.fetchedAt ? '刚刚检查过，请稍后再试' : '课表已更新');
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _status = '更新失败，请稍后重试';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final snapshot = ref.watch(academicCachedScheduleProvider(widget.uid));
    final at = snapshot.valueOrNull?.fetchedAt.toLocal();
    final updated = at == null
        ? snapshot.isLoading
              ? '正在读取更新时间…'
              : '尚未缓存课表'
        : '上次更新 ${at.year}/${at.month}/${at.day} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return SettingsRow(
      key: const ValueKey('academic-timetable-update-row'),
      leading: const Icon(AppIcons.calendar),
      title: '教务课表',
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.accountName}  $updated',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_status != null) ...[
            const SizedBox(height: 4),
            Text(
              _status!,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: _error ? p.danger : p.muted,
              ),
            ),
          ],
        ],
      ),
      stackSubtitleOnNarrow: true,
      trailing: OutlinedButton(
        key: const ValueKey('academic-timetable-update'),
        onPressed: _busy ? null : _refresh,
        child: Text(_busy ? '更新中…' : '更新'),
      ),
    );
  }
}

class _ExportLogsRow extends ConsumerStatefulWidget {
  const _ExportLogsRow();
  @override
  ConsumerState<_ExportLogsRow> createState() => _ExportLogsRowState();
}

class _ExportLogsRowState extends ConsumerState<_ExportLogsRow> {
  bool _busy = false;

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      final auth = ref.read(authControllerProvider);
      final monitor = ref.read(monitorControllerProvider);
      final roster = ref.read(assistControllerProvider);
      final selected = ref.read(selectedRollcallAccountProvider);
      final activeState = ref.read(activeRollcallsProvider(selected));
      final active = activeState.valueOrNull;
      final desktop = PlatformHooks.isDesktop;
      final counts = <String, int>{};
      for (final item in active ?? const []) {
        counts[item.type.name] = (counts[item.type.name] ?? 0) + 1;
      }
      final result = await AppLog.exportLogs(
        share: !desktop,
        sharePositionOrigin: origin,
        diagnostics: {
          'features': {
            'rollcallTypeResolver': 2,
            'qrEncodedPayload': true,
            'numberTimetableApi': true,
          },
          'session': {
            'signedIn': auth.isSignedIn,
            'selectedScope': selected == null ? 'owner' : 'assist',
            'lifecycle': WidgetsBinding.instance.lifecycleState?.name,
            'assistCount': roster.identities.length,
            'rosterReady': roster.ready,
          },
          'monitor': {
            'running': monitor.running,
            'consecutiveFailures': monitor.consecutiveFailures,
            'nextPollAt': monitor.nextPollAt?.toUtc().toIso8601String(),
          },
          'activeRollcalls': {
            'loaded': active != null,
            'loading': activeState.isLoading,
            'hasError': activeState.hasError,
            'count': active?.length,
            'typeCounts': counts,
          },
        },
      );
      if (!mounted) return;
      if (desktop && result != null) {
        final name = Uri.file(result.zipPath).pathSegments.last;
        final location = await file_selector.getSaveLocation(
          suggestedName: name,
          acceptedTypeGroups: const [
            file_selector.XTypeGroup(label: '诊断日志 ZIP', extensions: ['zip']),
          ],
        );
        if (location != null) {
          await file_selector.XFile(result.zipPath).saveTo(location.path);
        }
        if (!mounted) return;
        AppToast.show(
          context,
          location == null ? '已取消另存，日志包仍保留在本机' : '诊断日志已保存',
        );
        return;
      }
      AppToast.show(
        context,
        result == null
            ? '暂无日志可导出'
            : result.shareStatus == ShareResultStatus.dismissed
            ? '已取消分享，日志包已保留'
            : '日志包已生成并交给系统分享',
        error: result == null,
      );
    } catch (error) {
      if (mounted) AppToast.show(context, '导出失败，请重试', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SettingsRow(
    leading: const Icon(AppIcons.share),
    title: _busy ? '正在准备诊断日志…' : '导出诊断日志',
    subtitle: PlatformHooks.isDesktop
        ? '打包请求流水和错误详情，另存为 ZIP'
        : '包含请求流水、前后台日志和错误详情',
    trailing: _busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(AppIcons.right, size: 18),
    onTap: _busy ? null : _export,
  );
}
