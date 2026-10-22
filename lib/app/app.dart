import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/adaptive_shell.dart';
import 'package:xmu_rollcall/app/app_brand.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/cache/session_lifecycle.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/settings/settings_page.dart';
import 'package:xmu_rollcall/platform/android_monitor_shell.dart';
import 'package:xmu_rollcall/platform/desktop_shell.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class XmuRollcallApp extends ConsumerStatefulWidget {
  const XmuRollcallApp({super.key});

  @override
  ConsumerState<XmuRollcallApp> createState() => _XmuRollcallAppState();
}

class _XmuRollcallAppState extends ConsumerState<XmuRollcallApp> {
  @override
  void initState() {
    super.initState();
    // Restore the small cached profile while the HTTP client and install ID
    // initialize; profile verification can continue after the shell appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          ref.read(authControllerProvider).status == AuthStatus.unknown) {
        ref.read(authControllerProvider.notifier).bootstrap();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themePref = ref.watch(themePreferenceProvider);
    final bootstrap = ref.watch(appBootstrapProvider);
    ref.watch(sessionLifecycleProvider);

    final themeMode = switch (themePref) {
      ThemePreference.system => ThemeMode.system,
      ThemePreference.dark => ThemeMode.dark,
      ThemePreference.light => ThemeMode.light,
    };

    Widget app = MaterialApp(
      navigatorKey: _rootNavigatorKey,
      title: kAppDisplayName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: bootstrap.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('启动失败：$e'))),
        data: (_) => const _BootstrapAuth(),
      ),
    );

    if (PlatformHooks.isDesktop) {
      app = DesktopShellBinder(navigatorKey: _rootNavigatorKey, child: app);
    } else if (PlatformHooks.isAndroid) {
      app = _AndroidMonitorBinder(navigatorKey: _rootNavigatorKey, child: app);
    }

    // Windows AX bridge (flutter#182444) desyncs on tooltip/scroll/tab and
    // spams "N will not be in the tree…". Runner already swallows WM_GETOBJECT;
    // once the bridge is up (Cursor/devtools/hot-reload), stop emitting trees.
    // Narrator/UIA stay dark — accepted for this Quiet Utility (see runner).
    if (PlatformHooks.isWindows) {
      app = ExcludeSemantics(child: app);
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

class _AndroidMonitorBinderState extends ConsumerState<_AndroidMonitorBinder> {
  @override
  Widget build(BuildContext context) {
    ref.watch(monitorControllerProvider.select((s) => s.running));
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
      if (!mounted ||
          ref.read(authControllerProvider).status != AuthStatus.unknown) {
        return;
      }
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    // Only bootstrap uses AuthStatus.loading; sign-in must not tear down the shell.
    if (auth.status == AuthStatus.unknown ||
        auth.status == AuthStatus.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.status == AuthStatus.restoreFailed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(auth.errorMessage ?? '暂时无法恢复登录'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).bootstrap(),
                child: const Text('重新连接'),
              ),
              TextButton(
                onPressed: () => showLoginDialog(context),
                child: const Text('重新登录'),
              ),
            ],
          ),
        ),
      );
    }
    if (auth.isSignedIn && auth.errorMessage != null) {
      return Column(
        children: [
          Material(
            child: SafeArea(
              bottom: false,
              child: ListTile(
                title: Text(auth.errorMessage!),
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).bootstrap(),
                  child: const Text('重试'),
                ),
              ),
            ),
          ),
          const Expanded(child: AdaptiveShell()),
        ],
      );
    }
    return const AdaptiveShell();
  }
}
