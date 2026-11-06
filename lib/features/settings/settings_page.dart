import 'package:xmu_rollcall/features/schedule/semester_preferences.dart';
import 'package:xmu_rollcall/features/schedule/academic_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/mobile_campus_header.dart';
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
      if (AppDensity.isTouch(context))
        _SettingsAccountCard(
          title: auth.isSignedIn ? (auth.profile?.name ?? '已登录') : '未登录',
          subtitle: accountSubtitle,
          action: auth.isSignedIn
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: p.surface,
                    side: BorderSide(color: p.mobileOutline),
                    minimumSize: const Size(64, 44),
                  ),
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  child: const Text('退出'),
                )
              : FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 44),
                  ),
                  onPressed: () => showLoginDialog(context),
                  child: const Text('登录'),
                ),
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: p.surfaceHigh,
                child: Icon(AppIcons.person, size: 28, color: p.muted),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTruncatedText(
                      auth.isSignedIn ? (auth.profile?.name ?? '已登录') : '未登录',
                      style: AppTypography.sectionTitle.copyWith(
                        fontSize: 18,
                        color: p.ink,
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
                  ? TextButton(
                      onPressed: () async {
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
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
        children: [
          SettingsRow(
            leading: const Icon(AppIcons.theme),
            title: '外观',
            trailing: desktop
                ? AppSegmentedControl<ThemePreference>(
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
              subtitle: auth.isSignedIn ? '查看本周上课安排' : '请先登录',
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
              subtitle: desktop ? null : '自动检查，一次确认锁屏提醒',
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
        maxWidth: 808,
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
    final android = Theme.of(context).platform == TargetPlatform.android;
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
      leading: SizedBox(
        width: 24,
        child: Icon(icon, color: p.primary, size: 23),
      ),
      title: title,
      minHeight: android ? 48 : 52,
      contentPadding: EdgeInsets.symmetric(vertical: android ? 4 : 6),
      trailing: trailing ?? Icon(AppIcons.right, color: p.muted, size: 17),
      onTap: onTap,
    );
    Widget group(String title, List<Widget> rows) => Padding(
      padding: EdgeInsets.fromLTRB(
        android ? 16 : 20,
        android ? 16 : 20,
        android ? 16 : 20,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: p.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: p.border, indent: 36),
                    rows[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
    final appearance = AppShellSelect<ThemePreference>(
      semanticLabel: '外观模式',
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
      triggerBuilder: (context, open, toggle, focus) => TextButton(
        focusNode: focus,
        onPressed: toggle,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size(48, android ? 56 : 64),
          foregroundColor: p.ink,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Icon(AppIcons.theme, size: 23, color: p.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('外观', style: TextStyle(fontSize: 14))),
            Text(switch (preference) {
              ThemePreference.light => '浅色',
              ThemePreference.dark => '暗色',
              ThemePreference.system => '跟随系统',
            }, style: TextStyle(fontSize: 13, color: p.muted)),
            const SizedBox(width: 8),
            Icon(AppIcons.down, size: 14, color: p.muted),
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
              MobileCampusHeader(
                child: Theme.of(context).platform == TargetPlatform.android
                    ? _AndroidProfileHeader(
                        college: college,
                        semester: semester,
                        onSignOut: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                        name: auth.isSignedIn ? auth.profile!.name : '未登录',
                        subtitle: subtitle,
                        signedIn: auth.isSignedIn,
                        onTap: () => auth.isSignedIn
                            ? _showAccount(context, auth, subtitle)
                            : showLoginDialog(context),
                      )
                    : Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: p.accentSurface,
                            child: Icon(
                              AppIcons.person,
                              color: p.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.isSignedIn ? auth.profile!.name : '未登录',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: p.ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: p.muted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(48, 48),
                                    alignment: Alignment.centerLeft,
                                    foregroundColor: p.ink,
                                  ),
                                  onPressed: () => auth.isSignedIn
                                      ? _showAccount(context, auth, subtitle)
                                      : showLoginDialog(context),
                                  label: Text(
                                    auth.isSignedIn ? '账号管理' : '登录账号',
                                  ),
                                  icon: const Icon(AppIcons.right, size: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              group('常用', [
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
                ),
              ]),
              if ({
                TargetPlatform.windows,
                TargetPlatform.macOS,
                TargetPlatform.linux,
              }.contains(Theme.of(context).platform))
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: StartupSettings(),
                ),
              group('应用', [
                appearance,
                if (Theme.of(context).platform == TargetPlatform.android)
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
                const AboutSettingsRow(compact: true),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccount(BuildContext context, AuthState auth, String subtitle) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: false,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '账号管理',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const AppSheetCloseButton(),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                auth.profile!.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  ref.read(authControllerProvider.notifier).signOut();
                },
                child: const Text('退出登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single account summary anchors the personal page without nested cards.
class _SettingsAccountCard extends StatelessWidget {
  const _SettingsAccountCard({
    required this.title,
    required this.subtitle,
    required this.action,
  });
  final String title, subtitle;
  final Widget action;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return DecoratedBox(
      key: const ValueKey('settings-account-card'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(p.primary.withValues(alpha: .09), p.surface),
            p.surface,
          ],
        ),
        border: Border.all(color: p.mobileOutline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const BrandMark(size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.5, color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            action,
          ],
        ),
      ),
    );
  }
}

class _AndroidProfileHeader extends StatelessWidget {
  const _AndroidProfileHeader({
    required this.name,
    this.college,
    this.semester,
    required this.subtitle,
    required this.signedIn,
    required this.onTap,
    required this.onSignOut,
  });
  final String name, subtitle;
  final String? college, semester;
  final bool signedIn;
  final VoidCallback onTap, onSignOut;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: InkWell(
                key: const ValueKey('android-profile-summary'),
                onTap: onTap,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
              ),
            ),
            if (signedIn) ...[
              const SizedBox(width: 10),
              TextButton(
                onPressed: onSignOut,
                style: TextButton.styleFrom(
                  foregroundColor: p.muted,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('退出', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
        AppTruncatedText(
          subtitle,
          style: TextStyle(fontSize: 13, height: 1.5, color: p.muted),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (college?.trim().isNotEmpty == true)
                Text(
                  college!.trim(),
                  key: const ValueKey('profile-college'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.5, color: p.muted),
                ),
              if (semester != null)
                Text(
                  semester!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.5, color: p.muted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
