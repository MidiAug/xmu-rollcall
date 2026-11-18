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
import 'package:xmu_rollcall/features/settings/schedule_status_chip.dart';
import 'package:xmu_rollcall/features/rollcall/course_catalog_providers.dart';
import 'package:xmu_rollcall/features/settings/notification_settings_page.dart';
import 'package:xmu_rollcall/features/settings/desktop_notification_settings_page.dart';
import 'package:xmu_rollcall/features/settings/settings_assist_page.dart';
import 'package:xmu_rollcall/features/settings/settings_data_page.dart';
import 'package:xmu_rollcall/features/settings/about_settings_row.dart';
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
    final platform = Theme.of(context).platform;
    final desktop = switch (platform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };

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
              header: '常用',
              children: [
                SettingsRow(
                  leading: const Icon(Icons.calendar_view_week_outlined),
                  title: '本学期课表',
                  subtitle: auth.isSignedIn ? '查看本周上课安排' : '请先登录',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ref.watch(hasIncompleteCourseScheduleProvider)) ...[
                        const ScheduleStatusChip(),
                        const SizedBox(width: 8),
                      ],
                      Icon(Icons.chevron_right, color: p.muted, size: 18),
                    ],
                  ),
                  onTap: !auth.isSignedIn
                      ? () => showLoginDialog(context)
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
              ],
            ),
            SettingsSection(
              header: '应用',
              children: [
                SettingsRow(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: '外观',
                  trailing: AppShellSelect<ThemePreference>(
                    value: themePref,
                    items: const [
                      ThemePreference.light,
                      ThemePreference.dark,
                      ThemePreference.system,
                    ],
                    labelOf: (value) => switch (value) {
                      ThemePreference.light => '浅色',
                      ThemePreference.dark => '暗色',
                      ThemePreference.system => '跟随系统',
                    },
                    iconOf: (value) => switch (value) {
                      ThemePreference.light => Icons.wb_sunny_outlined,
                      ThemePreference.dark => Icons.dark_mode_outlined,
                      ThemePreference.system =>
                        PlatformHooks.systemAppearanceIcon(context),
                    },
                    width: 148,
                    onChanged: (v) {
                      ref.read(themePreferenceProvider.notifier).set(v);
                    },
                  ),
                ),
                if (desktop)
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
                if (platform == TargetPlatform.android || desktop)
                  SettingsRow(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: desktop ? '桌面提醒' : '后台提醒',
                    subtitle: desktop ? '测试系统通知与后台提醒' : '自动检查，一次确认锁屏提醒',
                    trailing: Icon(
                      Icons.chevron_right,
                      color: p.muted,
                      size: 18,
                    ),
                    onTap: () => AppPageRoutes.push(
                      context,
                      desktop
                          ? const DesktopNotificationSettingsPage()
                          : const NotificationSettingsPage(),
                    ),
                  ),
                SettingsRow(
                  leading: const Icon(Icons.storage_outlined),
                  title: '数据与诊断',
                  subtitle: '清除课程数据、本机标识与日志',
                  trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                  onTap: () =>
                      AppPageRoutes.push(context, const SettingsDataPage()),
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
