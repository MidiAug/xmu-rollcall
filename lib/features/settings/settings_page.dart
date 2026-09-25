import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/assist/assist_dialogs.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/location/saved_locations_page.dart';
import 'package:xmu_rollcall/features/rollcall/radar_preview.dart';
import 'package:xmu_rollcall/features/rollcall/session_prior_preview.dart';
import 'package:xmu_rollcall/features/settings/close_prefs_controller.dart';
import 'package:xmu_rollcall/features/settings/recent_logs_page.dart';
import 'package:xmu_rollcall/platform/android_monitor_shell.dart';
import 'package:xmu_rollcall/platform/close_prefs.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';
import 'package:xmu_rollcall/platform/shell_debug_preview.dart';

enum ThemePreference { system, dark, light }

final themePreferenceProvider =
    StateNotifierProvider<ThemePreferenceController, ThemePreference>((ref) {
      return ThemePreferenceController();
    });

class ThemePreferenceController extends StateNotifier<ThemePreference> {
  ThemePreferenceController() : super(ThemePreference.dark) {
    _load();
  }

  static const _key = 'theme_preference';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final i = prefs.getInt(_key) ?? ThemePreference.dark.index;
    state =
        ThemePreference.values[i.clamp(0, ThemePreference.values.length - 1)];
  }

  Future<void> set(ThemePreference value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value.index);
  }
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with ShellTabAware<SettingsPage> {
  final _scroll = ScrollController();

  @override
  AppDestination get shellTab => AppDestination.settings;

  @override
  ScrollController? get shellScrollController => _scroll;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final themePref = ref.watch(themePreferenceProvider);
    final assist = ref.watch(assistControllerProvider);
    final deviceFuture = ref.watch(deviceIdentityProvider).getId();
    final p = AppPalette.of(context);

    return PageScaffold(
      title: '我的',
      showHeader: false,
      child: AppContentColumn(
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            AppSpace.pageXOf(context),
            AppSpace.md,
            AppSpace.pageXOf(context),
            AppSpace.xl,
          ),
          children: [
          SettingsSection(
            padTop: false,
            header: '账号',
            children: [
              SettingsRow(
                leading: const BrandMark(size: 36),
                title: auth.isSignedIn ? (auth.profile?.name ?? '已登录') : '未登录',
                subtitle: auth.isSignedIn
                    ? 'ID ${auth.profile?.id ?? "-"}'
                    : '使用学号密码登录',
                trailing: auth.isSignedIn
                    ? TextButton(
                        onPressed: () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .signOut();
                        },
                        child: const Text('退出'),
                      )
                    : FilledButton(
                        onPressed: () => showLoginDialog(context),
                        child: const Text('登录'),
                      ),
              ),
            ],
          ),
          SettingsSection(
            header: '外观',
            hasLeading: false,
            children: [
              Padding(
                padding: AppDensity.rowPadding(context),
                child: AppChoiceCubes<ThemePreference>(
                  value: themePref,
                  onChanged: (v) {
                    ref.read(themePreferenceProvider.notifier).set(v);
                  },
                  cubes: [
                    const AppChoiceCube(
                      value: ThemePreference.light,
                      label: '浅色',
                      icon: Icons.wb_sunny_outlined,
                    ),
                    const AppChoiceCube(
                      value: ThemePreference.dark,
                      label: '暗色',
                      icon: Icons.dark_mode_outlined,
                    ),
                    AppChoiceCube(
                      value: ThemePreference.system,
                      label: '系统',
                      icon: PlatformHooks.systemAppearanceIcon(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (PlatformHooks.isDesktop)
            SettingsSection(
              header: '窗口',
              children: [
                SettingsRow(
                  leading: const Icon(Icons.desktop_windows_outlined),
                  title: '关闭窗口时',
                  subtitle: '询问 / 托盘 / 退出',
                  trailing: AppShellSelect<CloseMode>(
                    value: ref.watch(closePrefsProvider).mode,
                    items: CloseMode.values,
                    labelOf: (m) => m.label,
                    width: 148,
                    onChanged: (m) {
                      ref.read(closePrefsProvider.notifier).setMode(m);
                    },
                  ),
                ),
              ],
            ),
          if (PlatformHooks.isAndroid)
            SettingsSection(
              header: '后台检测',
              children: [
                SettingsRow(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: '常驻通知',
                  subtitle: '开启自动检测后，通知栏显示倒计时；发现签到会另发提醒',
                ),
                SettingsRow(
                  leading: const Icon(Icons.battery_saver_outlined),
                  title: '忽略电池优化',
                  subtitle: '部分机型需允许，否则回桌后可能停检',
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                  onTap: () => AndroidMonitorShell.instance
                      .openBatteryOptimizationSettings(),
                ),
              ],
            ),
          SettingsSection(
            header: '位置',
            children: [
              SettingsRow(
                leading: const Icon(Icons.place_outlined),
                title: '预设位置',
                subtitle: '管理常用签到位置',
                trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                onTap: () => AppPageRoutes.push(context, const SavedLocationsPage()),
              ),
            ],
          ),
          SettingsSection(
            header: '协助签到',
            children: [
              SettingsRow(
                leading: const Icon(Icons.upload_outlined),
                title: '导出协助码',
                subtitle: auth.isSignedIn ? '生成后复制给同学' : '请先登录',
                trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                onTap: !auth.isSignedIn || assist.busy
                    ? null
                    : () => showAssistExportDialog(
                          context,
                          export: (kind) => ref
                              .read(assistControllerProvider.notifier)
                              .exportOwner(kind: kind),
                        ),
              ),
              SettingsRow(
                leading: const Icon(Icons.download_outlined),
                title: '导入协助身份',
                subtitle: '粘贴协助码或输入学号密码',
                trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                onTap: assist.busy
                    ? null
                    : () => showAssistImportDialog(
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
                              .importPlainAccount(
                                username: user,
                                password: pass,
                              );
                          if (context.mounted) {
                            AppToast.show(
                              context,
                              '已导入 ${id.displayName}（${id.kind.labelZh}，同课 ${id.sharedCourses.length} 门）',
                            );
                          }
                        },
                      ),
              ),
              SettingsRow(
                leading: const Icon(Icons.group_outlined),
                title: '已导入名单',
                subtitle: assist.ready ? '${assist.identities.length} 人' : '…',
                trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                onTap: () => AppPageRoutes.push(context, const AssistIdentitiesPage()),
              ),
            ],
          ),
          SettingsSection(
            header: '设备与诊断',
            children: [
              FutureBuilder<String>(
                future: deviceFuture,
                builder: (context, snap) {
                  return SettingsRow(
                    leading: const Icon(Icons.devices_outlined),
                    title: '设备 ID',
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
                              fontFamilyFallback: const ['Menlo', 'monospace'],
                            ),
                          ),
                    subtitle: '用于识别本机，重装前保持不变',
                  );
                },
              ),
              SettingsRow(
                leading: const Icon(Icons.receipt_long_outlined),
                title: '最近日志',
                subtitle: '本机诊断事件，可按 opId / 签到 ID 搜索',
                trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                onTap: () => AppPageRoutes.push(context, const RecentLogsPage()),
              ),
              SettingsRow(
                leading: const Icon(Icons.ios_share_outlined),
                title: '导出日志',
                subtitle: '打包 NDJSON + manifest，经系统分享',
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
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
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
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
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
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
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
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
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
}
