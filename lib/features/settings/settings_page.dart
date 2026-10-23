import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/location/saved_locations_page.dart';
import 'package:xmu_rollcall/features/settings/close_prefs_controller.dart';
import 'package:xmu_rollcall/features/settings/courses_page.dart';
import 'package:xmu_rollcall/features/settings/notification_settings_page.dart';
import 'package:xmu_rollcall/features/settings/desktop_notification_settings_page.dart';
import 'package:xmu_rollcall/features/settings/settings_assist_page.dart';
import 'package:xmu_rollcall/features/settings/settings_data_page.dart';
import 'package:xmu_rollcall/features/settings/about_settings_row.dart';
import 'package:xmu_rollcall/features/update/update_download_route_dialog.dart';
import 'package:xmu_rollcall/platform/close_prefs.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

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
    final p = AppPalette.of(context);

    final accountSubtitle = !auth.isSignedIn
        ? (auth.errorMessage ?? '使用学号密码登录')
        : (auth.profile?.studentNo ??
              (auth.profile?.email?.isNotEmpty == true
                  ? auth.profile!.email!
                  : '已登录'));

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
                  title: auth.isSignedIn
                      ? (auth.profile?.name ?? '已登录')
                      : '未登录',
                  subtitle: accountSubtitle,
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
            SettingsSection(
              header: '常用',
              children: [
                SettingsRow(
                  leading: const Icon(Icons.calendar_view_week_outlined),
                  title: '本学期课表',
                  subtitle: auth.isSignedIn ? '查看本周上课安排' : '请先登录',
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                  onTap: !auth.isSignedIn
                      ? null
                      : () => AppPageRoutes.push(context, const CoursesPage()),
                ),
                SettingsRow(
                  leading: const Icon(Icons.place_outlined),
                  title: '常用地点',
                  subtitle: '管理签到时常用的位置',
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                  onTap: () =>
                      AppPageRoutes.push(context, const SavedLocationsPage()),
                ),
              ],
            ),
            if (PlatformHooks.isAndroid || PlatformHooks.isDesktop)
              SettingsSection(
                header: '检测',
                children: [
                  SettingsRow(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: PlatformHooks.isDesktop ? '桌面提醒' : '后台提醒',
                    subtitle: PlatformHooks.isDesktop
                        ? '测试系统通知，检查托盘状态'
                        : '自动检查，一次确认锁屏提醒',
                    trailing: Icon(
                      Icons.chevron_right,
                      color: p.muted,
                      size: 18,
                    ),
                    onTap: () => AppPageRoutes.push(
                      context,
                      PlatformHooks.isDesktop
                          ? const DesktopNotificationSettingsPage()
                          : const NotificationSettingsPage(),
                    ),
                  ),
                ],
              ),
            SettingsSection(
              header: '更多',
              children: [
                SettingsRow(
                  leading: const Icon(Icons.handshake_outlined),
                  title: '协助同学',
                  subtitle: assist.ready && assist.identities.isNotEmpty
                      ? '已导入 ${assist.identities.length} 人'
                      : '导出或导入协助身份',
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                  onTap: () =>
                      AppPageRoutes.push(context, const SettingsAssistPage()),
                ),
                SettingsRow(
                  leading: const Icon(Icons.storage_outlined),
                  title: '数据与诊断',
                  subtitle: '清除课程数据、本机标识与日志',
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                  onTap: () =>
                      AppPageRoutes.push(context, const SettingsDataPage()),
                ),
                SettingsRow(
                  leading: const Icon(Icons.download_outlined),
                  title: '更新下载线路',
                  subtitle: '官方地址或 HTTPS 加速节点',
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                  onTap: () => showUpdateDownloadRouteDialog(context),
                ),
                const AboutSettingsRow(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
