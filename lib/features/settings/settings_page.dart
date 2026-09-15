import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';

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
    state = ThemePreference.values[i.clamp(0, ThemePreference.values.length - 1)];
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
  }

  Future<void> set(bool value) async {
    state = value;
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: Text(
              auth.isSignedIn ? (auth.profile?.name ?? '已登录') : '未登录',
            ),
            subtitle: Text(
              auth.isSignedIn
                  ? 'ID ${auth.profile?.id ?? "—"}'
                  : '登录厦大统一身份认证后使用畅课签到',
            ),
            trailing: auth.isSignedIn
                ? TextButton(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                    },
                    child: const Text('退出'),
                  )
                : FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginPage(),
                        ),
                      );
                    },
                    child: const Text('登录'),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Text('外观', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<ThemePreference>(
          segments: const [
            ButtonSegment(value: ThemePreference.system, label: Text('跟随')),
            ButtonSegment(value: ThemePreference.dark, label: Text('暗色')),
            ButtonSegment(value: ThemePreference.light, label: Text('浅色')),
          ],
          selected: {themePref},
          onSelectionChanged: (s) {
            ref.read(themePreferenceProvider.notifier).set(s.first);
          },
        ),
        const SizedBox(height: 24),
        Text('设备', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        FutureBuilder<String>(
          future: deviceFuture,
          builder: (context, snap) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('设备 ID（稳定）'),
              subtitle: Text(
                snap.data ?? '…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
        ),
        Text(
          '安装后持久化，不会每次请求随机生成（KB-01）。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('诊断日志'),
          subtitle: const Text('本地开关；勿把密码写入日志'),
          value: diagnostics,
          onChanged: (v) =>
              ref.read(diagnosticsEnabledProvider.notifier).set(v),
        ),
        const SizedBox(height: 24),
        Text(
          'xmu-rollcall · 本人到课客户端\n默认不开启自动签到 / PIN 爆破 / 假定位代签',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
