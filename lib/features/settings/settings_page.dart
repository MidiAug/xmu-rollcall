import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/location/saved_locations_page.dart';

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
    state = ThemePreference
        .values[i.clamp(0, ThemePreference.values.length - 1)];
  }

  Future<void> set(ThemePreference value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value.index);
  }
}

final diagnosticsEnabledProvider =
    StateNotifierProvider<DiagnosticsController, bool>((ref) {
  return DiagnosticsController();
});

class DiagnosticsController extends StateNotifier<bool> {
  DiagnosticsController() : super(false) {
    _load();
  }

  static const _key = 'diagnostics_enabled';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
    AppLog.enabled = state;
  }

  Future<void> set(bool value) async {
    state = value;
    AppLog.enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final themePref = ref.watch(themePreferenceProvider);
    final diagnostics = ref.watch(diagnosticsEnabledProvider);
    final deviceFuture = ref.watch(deviceIdentityProvider).getId();
    final p = AppPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;

    return PageScaffold(
      title: '我的',
      subtitle: '账号与客户端偏好',
      showHeader: wide,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.pageX,
          AppSpace.md,
          AppSpace.pageX,
          AppSpace.xl,
        ),
        children: [
          SettingsSection(
            header: '账号',
            children: [
              SettingsRow(
                leading: const BrandMark(size: 36),
                title: auth.isSignedIn
                    ? (auth.profile?.name ?? '已登录')
                    : '未登录',
                subtitle: auth.isSignedIn
                    ? 'ID ${auth.profile?.id ?? "-"}'
                    : '学号密码登录畅课会话',
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
          const SizedBox(height: AppSpace.stack),
          SettingsSection(
            header: '外观',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.md,
                  AppSpace.md,
                  AppSpace.md,
                ),
                child: AppSegmentedControl<ThemePreference>(
                  expanded: true,
                  value: themePref,
                  onChanged: (v) {
                    ref.read(themePreferenceProvider.notifier).set(v);
                  },
                  segments: const [
                    AppSegment(
                      value: ThemePreference.system,
                      label: '跟随',
                    ),
                    AppSegment(
                      value: ThemePreference.dark,
                      label: '暗色',
                    ),
                    AppSegment(
                      value: ThemePreference.light,
                      label: '浅色',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.stack),
          SettingsSection(
            header: '位置',
            children: [
              SettingsRow(
                leading: const Icon(Icons.place_outlined),
                title: '预设位置',
                subtitle: '地图添加与管理',
                trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      transitionDuration: AppMotion.duration,
                      reverseTransitionDuration: AppMotion.duration,
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const SavedLocationsPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: CurvedAnimation(
                            parent: animation,
                            curve: AppMotion.curve,
                          ),
                          child: child,
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpace.stack),
          SettingsSection(
            header: '设备与诊断',
            children: [
              FutureBuilder<String>(
                future: deviceFuture,
                builder: (context, snap) {
                  return SettingsRow(
                    leading: const Icon(Icons.devices_outlined),
                    title: '设备 ID（稳定）',
                    subtitleWidget: snap.data == null
                        ? Text('…', style: TextStyle(color: p.muted, fontSize: 12))
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
                    subtitle: '安装后持久化，不会每次请求随机生成。',
                  );
                },
              ),
              SettingsRow(
                leading: const Icon(Icons.bug_report_outlined),
                title: '诊断日志',
                subtitle: '本地开关；勿把密码写入日志',
                trailing: Switch.adaptive(
                  value: diagnostics,
                  onChanged: (v) =>
                      ref.read(diagnosticsEnabledProvider.notifier).set(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          Text(
            'xmu-rollcall 本人到课客户端。默认不开启自动签到、PIN 爆破或假定位代签。',
            style: TextStyle(fontSize: 12, height: 1.45, color: p.muted),
          ),
        ],
      ),
    );
  }
}
