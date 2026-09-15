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
          AppSpace.xxs,
          AppSpace.pageX,
          AppSpace.xl,
        ),
        children: [
          Panel(
            child: Row(
              children: [
                const BrandMark(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.isSignedIn
                            ? (auth.profile?.name ?? '已登录')
                            : '未登录',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        auth.isSignedIn
                            ? 'ID ${auth.profile?.id ?? "-"}'
                            : '学号密码登录畅课会话',
                        style: TextStyle(
                          fontSize: 12,
                          color: p.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (auth.isSignedIn)
                  OutlinedButton(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                    },
                    child: const Text('退出'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => showLoginDialog(context),
                    icon: const Icon(Icons.login, size: 16),
                    label: const Text('登录'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.stack),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '外观',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                SegmentedButton<ThemePreference>(
                  segments: const [
                    ButtonSegment(
                      value: ThemePreference.system,
                      icon: Icon(Icons.brightness_auto_outlined, size: 16),
                      label: Text('跟随'),
                    ),
                    ButtonSegment(
                      value: ThemePreference.dark,
                      icon: Icon(Icons.dark_mode_outlined, size: 16),
                      label: Text('暗色'),
                    ),
                    ButtonSegment(
                      value: ThemePreference.light,
                      icon: Icon(Icons.light_mode_outlined, size: 16),
                      label: Text('浅色'),
                    ),
                  ],
                  selected: {themePref},
                  onSelectionChanged: (s) {
                    ref.read(themePreferenceProvider.notifier).set(s.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.stack),
          Panel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.place_outlined, color: p.primary),
              title: const Text('预设位置'),
              subtitle: Text(
                '地图添加与管理',
                style: TextStyle(fontSize: 12, color: p.muted),
              ),
              trailing: Icon(Icons.chevron_right, color: p.muted, size: 18),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SavedLocationsPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpace.stack),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设备 ID（稳定）',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                FutureBuilder<String>(
                  future: deviceFuture,
                  builder: (context, snap) {
                    return SelectableText(
                      snap.data ?? '…',
                      style: TextStyle(
                        fontSize: 12,
                        color: p.muted,
                        fontFamily: 'Consolas',
                        fontFamilyFallback: const ['Menlo', 'monospace'],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '安装后持久化，不会每次请求随机生成。',
                  style: TextStyle(fontSize: 12, color: p.muted),
                ),
                const SizedBox(height: AppSpace.sm),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('诊断日志'),
                    subtitle: const Text('本地开关；勿把密码写入日志'),
                    value: diagnostics,
                    onChanged: (v) =>
                        ref.read(diagnosticsEnabledProvider.notifier).set(v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'xmu-rollcall 本人到课客户端。默认不开启自动签到、PIN 爆破或假定位代签。',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ],
      ),
    );
  }
}
