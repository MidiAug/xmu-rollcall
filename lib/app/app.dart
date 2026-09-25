import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/adaptive_shell.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/settings/settings_page.dart';
import 'package:xmu_rollcall/platform/android_monitor_shell.dart';
import 'package:xmu_rollcall/platform/desktop_shell.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

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

    Widget app = MaterialApp(
      navigatorKey: _rootNavigatorKey,
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

    if (PlatformHooks.isDesktop) {
      app = DesktopShellBinder(
        navigatorKey: _rootNavigatorKey,
        child: app,
      );
    } else if (PlatformHooks.isAndroid) {
      app = _AndroidMonitorBinder(
        navigatorKey: _rootNavigatorKey,
        child: app,
      );
    }

    return app;
  }
}

class _AndroidMonitorBinder extends ConsumerStatefulWidget {
  const _AndroidMonitorBinder({
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<_AndroidMonitorBinder> createState() =>
      _AndroidMonitorBinderState();
}

class _AndroidMonitorBinderState
    extends ConsumerState<_AndroidMonitorBinder> {
  @override
  Widget build(BuildContext context) {
    return AndroidMonitorShellBinder(
      stopMonitor: () {
        ref.read(monitorControllerProvider.notifier).stop();
      },
      onUserMessage: (message) {
        final ctx = widget.navigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) return;
        AppToast.show(ctx, message);
      },
      child: widget.child,
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
