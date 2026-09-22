import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/adaptive_shell.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/settings/settings_page.dart';

class XmuRollcallApp extends ConsumerWidget {
  const XmuRollcallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePref = ref.watch(themePreferenceProvider);
    final bootstrap = ref.watch(appBootstrapProvider);

    final themeMode = switch (themePref) {
      ThemePreference.system => ThemeMode.system,
      ThemePreference.dark => ThemeMode.dark,
      ThemePreference.light => ThemeMode.light,
    };

    return MaterialApp(
      title: 'xmu-rollcall',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: bootstrap.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          body: Center(child: Text('启动失败：$e')),
        ),
        data: (_) => const _BootstrapAuth(),
      ),
    );
  }
}

class _BootstrapAuth extends ConsumerStatefulWidget {
  const _BootstrapAuth();

  @override
  ConsumerState<_BootstrapAuth> createState() => _BootstrapAuthState();
}

class _BootstrapAuthState extends ConsumerState<_BootstrapAuth> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    // Only bootstrap uses AuthStatus.loading; sign-in must not tear down the shell.
    if (auth.status == AuthStatus.unknown ||
        auth.status == AuthStatus.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const AdaptiveShell();
  }
}
