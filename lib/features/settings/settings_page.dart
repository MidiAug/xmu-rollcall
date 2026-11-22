import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
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
import 'package:xmu_rollcall/features/settings/startup_settings.dart';
import 'package:xmu_rollcall/platform/close_prefs.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';
import 'package:xmu_rollcall/features/browser/browser_preferences.dart';

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

    if (AppMobileUi.useTouchChrome(context)) {
      return _mobilePage(context, auth, themePref, accountSubtitle);
    }

    // Keep the controls independent of the live centering gutter.
    final sections = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xxs,
          0,
          AppSpace.md,
          AppSpace.md,
        ),
        child: Row(
          children: [
            AppIdentityAvatar(
              name: auth.isSignedIn ? auth.profile?.name : null,
              size: 48,
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppHoverSurface(
                    quiet: true,
                    outlined: false,
                    onTap: () => auth.isSignedIn
                        ? _showAccount(context)
                        : showLoginDialog(context),
                    child: AppTruncatedText(
                      auth.isSignedIn ? (auth.profile?.name ?? '已登录') : '未登录',
                      style: AppTypography.sectionTitle.copyWith(
                        fontSize: 18,
                        color: p.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  Text(
                    accountSubtitle,
                    maxLines: 2,
                    style: AppTypography.caption.copyWith(color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.md),
            auth.isSignedIn
                ? OutlinedButton(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                    },
                    child: const Text('退出'),
                  )
                : TextButton(
                    onPressed: () => showLoginDialog(context),
                    child: const Text('登录'),
                  ),
          ],
        ),
      ),
      SettingsSection(
        header: desktop ? null : '应用',
        padTop: false,
        children: [
          SettingsRow(
            leading: const Icon(AppIcons.theme),
            title: '外观',
            trailing: desktop
                ? AppSegmentedControl<ThemePreference>(
                    compact: true,
                    segments: const [
                      AppSegment(value: ThemePreference.light, label: '浅色'),
                      AppSegment(value: ThemePreference.dark, label: '暗色'),
                      AppSegment(value: ThemePreference.system, label: '跟随系统'),
                    ],
                    value: themePref,
                    onChanged: (value) =>
                        ref.read(themePreferenceProvider.notifier).set(value),
                  )
                : AppShellSelect<ThemePreference>(
                    semanticLabel: '外观模式',
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
                      ThemePreference.light => AppIcons.sun,
                      ThemePreference.dark => AppIcons.moon,
                      ThemePreference.system =>
                        PlatformHooks.systemAppearanceIcon(context),
                    },
                    width: 148,
                    onChanged: (v) {
                      ref.read(themePreferenceProvider.notifier).set(v);
                    },
                  ),
          ),
          if (platform == TargetPlatform.windows)
            SettingsRow(
              leading: const Icon(AppIcons.externalLink),
              title: '常用网站打开方式',
              trailing: AppShellSelect<WebsiteOpenMode>(
                semanticLabel: '常用网站打开方式',
                value: ref.watch(websiteOpenModeProvider),
                plain: true,
                compact: true,
                items: WebsiteOpenMode.values,
                labelOf: (mode) => mode.label,
                width: 148,
                menuWidth: 200,
                onChanged: (mode) =>
                    ref.read(websiteOpenModeProvider.notifier).set(mode),
              ),
            ),
          if (desktop)
            SettingsRow(
              leading: const Icon(AppIcons.desktop),
              title: '关闭窗口时',
              trailing: AppShellSelect<CloseMode>(
                semanticLabel: '关闭窗口时',
                plain: true,
                compact: true,
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
        header: desktop ? null : '常用',
        children: [
          if (!desktop)
            SettingsRow(
              leading: const Icon(AppIcons.week),
              title: '本学期课表',
              subtitle: auth.isSignedIn ? null : '请先登录',
              trailing: Icon(AppIcons.right, color: p.muted, size: 18),
              onTap: !auth.isSignedIn
                  ? () => showLoginDialog(context)
                  : () => AppPageRoutes.push(context, const CoursesPage()),
            ),
          SettingsRow(
            leading: const Icon(AppIcons.location),
            title: '地点管理',
            trailing: Icon(AppIcons.right, color: p.muted, size: 18),
            onTap: () =>
                AppPageRoutes.push(context, const SavedLocationsPage()),
          ),
          SettingsRow(
            leading: const Icon(AppIcons.assist),
            title: '协助同学',
            subtitle: assist.ready && assist.identities.isNotEmpty
                ? '已导入 ${assist.identities.length} 人'
                : null,
            trailing: Icon(AppIcons.right, color: p.muted, size: 18),
            onTap: () =>
                AppPageRoutes.push(context, const SettingsAssistPage()),
          ),
        ],
      ),
      if (desktop) const StartupSettings(showHeader: false),
      SettingsSection(
        header: desktop ? null : '通知与数据',
        children: [
          if (platform == TargetPlatform.android || desktop)
            SettingsRow(
              leading: const Icon(AppIcons.notification),
              title: desktop ? '桌面提醒' : '后台提醒',
              trailing: Icon(AppIcons.right, color: p.muted, size: 18),
              onTap: () => AppPageRoutes.push(
                context,
                desktop
                    ? const DesktopNotificationSettingsPage()
                    : const NotificationSettingsPage(),
              ),
            ),
          SettingsRow(
            leading: const Icon(AppIcons.data),
            title: '数据与诊断',
            trailing: Icon(AppIcons.right, color: p.muted, size: 18),
            onTap: () => AppPageRoutes.push(context, const SettingsDataPage()),
          ),
          const AboutSettingsRow(),
        ],
      ),
    ];

    return PageScaffold(
      title: PlatformHooks.isDesktop && !AppDensity.isTouch(context)
          ? '设置'
          : '我的',
      showHeader: false,
      child: AppPageViewport(
        builder: (context, contentInsets) => ListView(
          controller: _scroll,
          padding:
              contentInsets +
              EdgeInsets.fromLTRB(
                AppSpace.pageXOf(context),
                AppSpace.xl,
                AppSpace.pageXOf(context),
                AppSpace.xl,
              ),
          children: sections,
        ),
      ),
    );
  }

  Widget _mobilePage(
    BuildContext context,
    AuthState auth,
    ThemePreference preference,
    String subtitle,
  ) {
    final p = AppPalette.of(context);
    final platform = Theme.of(context).platform;
    final android = platform == TargetPlatform.android;
    final assist = ref.watch(assistControllerProvider);
    final college = android && auth.isSignedIn
        ? ref
              .watch(academicCachedScheduleProvider(auth.profile!.id))
              .valueOrNull
              ?.studentCollege
        : null;
    final termInfo = android && auth.isSignedIn
        ? ref.watch(semesterInfoProvider(auth.profile!.id)).valueOrNull
        : null;
    final semester = termInfo == null
        ? null
        : '${semesterLabel(termInfo.term)}  ${termInfo.weekLabel(DateTime.now())}';
    Widget row(
      IconData icon,
      String title,
      VoidCallback onTap, {
      Widget? trailing,
    }) => SettingsRow(
      leading: Icon(icon, color: p.muted, size: 22),
      title: title,
      trailing: trailing ?? Icon(AppIcons.right, color: p.muted, size: 18),
      onTap: onTap,
    );
    Widget group(List<Widget> rows) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: SettingsSection(padTop: false, children: rows),
    );
    final appearance = AppShellSelect<ThemePreference>(
      semanticLabel: '外观模式',
      menuTitle: '外观',
      highlightSelection: true,
      value: preference,
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
      width: double.infinity,
      triggerBuilder: (context, open, toggle, focus) => SettingsRow(
        focusNode: focus,
        leading: Icon(AppIcons.theme, color: p.muted, size: 22),
        title: '外观',
        onTap: toggle,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(switch (preference) {
              ThemePreference.light => '浅色',
              ThemePreference.dark => '暗色',
              ThemePreference.system => '跟随系统',
            }, style: AppTypography.body.copyWith(color: p.muted)),
            const SizedBox(width: 8),
            Icon(AppIcons.right, size: 18, color: p.muted),
          ],
        ),
      ),
      onChanged: (value) =>
          ref.read(themePreferenceProvider.notifier).set(value),
    );
    return PageScaffold(
      title: '我的',
      showHeader: false,
      child: AppContentColumn(
        child: ColoredBox(
          color: p.mobileCanvas,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Text(
                  '我的',
                  style: AppTypography.pageTitle.copyWith(
                    fontSize: 28,
                    color: p.ink,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SettingsSection(
                  padTop: false,
                  children: [
                    SettingsRow(
                      key: const ValueKey('android-profile-summary'),
                      leadingSize: 44,
                      leading: AppIdentityAvatar(
                        name: auth.isSignedIn ? auth.profile?.name : null,
                        size: 44,
                      ),
                      title: auth.isSignedIn ? auth.profile!.name : '未登录',
                      subtitle: auth.isSignedIn ? '主账号' : subtitle,
                      trailing: Icon(AppIcons.right, size: 18, color: p.muted),
                      onTap: () => auth.isSignedIn
                          ? _showAccount(context)
                          : showLoginDialog(context),
                    ),
                    if (college?.trim().isNotEmpty == true || semester != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (college?.trim().isNotEmpty == true)
                              Text(
                                college!.trim(),
                                key: const ValueKey('profile-college'),
                                style: AppTypography.caption.copyWith(
                                  color: p.muted,
                                ),
                              ),
                            if (semester != null)
                              Text(
                                semester,
                                style: AppTypography.caption.copyWith(
                                  color: p.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              group([
                row(
                  AppIcons.calendar,
                  '本学期课表',
                  () => AppPageRoutes.push(context, const CoursesPage()),
                ),
                row(
                  AppIcons.location,
                  '地点管理',
                  () => AppPageRoutes.push(context, const SavedLocationsPage()),
                ),
                row(
                  AppIcons.assist,
                  '协助同学',
                  () => AppPageRoutes.push(context, const SettingsAssistPage()),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        assist.ready
                            ? '已导入 ${assist.identities.length} 人'
                            : '…',
                        style: AppTypography.body.copyWith(color: p.muted),
                      ),
                      const SizedBox(width: 8),
                      Icon(AppIcons.right, size: 18, color: p.muted),
                    ],
                  ),
                ),
              ]),
              if ({
                TargetPlatform.windows,
                TargetPlatform.macOS,
                TargetPlatform.linux,
              }.contains(platform))
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: StartupSettings(),
                ),
              group([
                appearance,
                if (android)
                  row(
                    AppIcons.notification,
                    '后台提醒',
                    () => AppPageRoutes.push(
                      context,
                      const NotificationSettingsPage(),
                    ),
                  ),
                row(
                  AppIcons.data,
                  '数据与诊断',
                  () => AppPageRoutes.push(context, const SettingsDataPage()),
                ),
                const AboutSettingsRow(),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccount(BuildContext context) {
    AppPageRoutes.push(context, const _AccountManagementPage());
  }
}

class _AccountManagementPage extends ConsumerWidget {
  const _AccountManagementPage();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final p = AppPalette.of(context);
    final name = auth.profile?.name ?? '未登录';
    return SubpageScaffold(
      title: '账号管理',
      body: AppPageViewport(
        builder: (context, insets) => ListView(
          padding: insets + EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            Panel(
              lifted: true,
              outlined: true,
              child: Row(
                children: [
                  AppIdentityAvatar(name: name, size: 52),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTypography.cardTitle.copyWith(color: p.ink),
                        ),
                        const SizedBox(height: 6),
                        if (auth.isSignedIn)
                          const AppStatusBadge(
                            '主账号',
                            tone: AppStatusTone.accent,
                            pill: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SettingsSection(
              padTop: false,
              hasLeading: false,
              children: [
                SettingsRow(
                  title: '当前身份',
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(name, textAlign: TextAlign.end),
                    ),
                  ),
                ),
                if (auth.isSignedIn)
                  const SettingsRow(title: '账号级别', trailing: Text('主账号')),
                if (auth.profile?.studentNo?.isNotEmpty == true)
                  SettingsRow(
                    title: '学号',
                    trailing: Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SelectableText(
                          auth.profile!.studentNo!,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (auth.isSignedIn)
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: AppDensity.isTouch(context) ? double.infinity : null,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.danger,
                      side: BorderSide(color: p.dangerRim),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      ref.read(authControllerProvider.notifier).signOut();
                    },
                    child: const Text('退出登录'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
