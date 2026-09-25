import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/desktop_shell_chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/homework/homework_hub_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_hub_page.dart';
import 'package:xmu_rollcall/features/settings/settings_page.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key});

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  AppDestination _current = AppDestination.rollcall;
  int _retapEpoch = 0;
  AppDestination? _retapDestination;

  final _chrome = DesktopShellChromeController();

  final _navKeys = List<GlobalKey<NavigatorState>>.generate(
    AppDestination.values.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  void dispose() {
    _chrome.dispose();
    super.dispose();
  }

  void _onSelect(AppDestination d) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (d == _current) {
      _navKeys[d.index].currentState?.popUntil((route) => route.isFirst);
      setState(() {
        _retapEpoch++;
        _retapDestination = d;
      });
      return;
    }
    setState(() => _current = d);
    _chrome.current = d;
  }

  Widget _tabNavigator(AppDestination d, Widget home) {
    return ShellTabDestination(
      destination: d,
      child: Navigator(
        key: _navKeys[d.index],
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => home,
          );
        },
      ),
    );
  }

  void _onSystemBack() {
    final nav = _navKeys[_current.index].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }
    if (!PlatformHooks.isDesktop) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;
    final body = IndexedStack(
      index: _current.index,
      children: [
        _tabNavigator(AppDestination.rollcall, const RollcallHubPage()),
        _tabNavigator(AppDestination.homework, const HomeworkHubPage()),
        _tabNavigator(AppDestination.settings, const SettingsPage()),
      ],
    );
    final showTitleBar = PlatformHooks.isDesktop;

    final scaffold = wide
        ? Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: p.canvas,
            body: Column(
              children: [
                if (showTitleBar) const AppTitleBar(title: '畅课签到'),
                if (showTitleBar) Container(height: 1, color: p.border),
                Expanded(
                  child: Row(
                    children: [
                      Consumer(
                        builder: (context, ref, _) {
                          final name =
                              ref.watch(authControllerProvider).profile?.name;
                          return AppSidebar(
                            current: _current,
                            onSelect: _onSelect,
                            userLabel: name,
                          );
                        },
                      ),
                      Container(width: 1, color: p.border),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: p.canvas,
            body: Column(
              children: [
                if (showTitleBar) const AppTitleBar(title: '畅课签到'),
                Expanded(
                  child: SafeArea(
                    // Top inset owned by PageScaffold / SubpageScaffold (R-23).
                    top: false,
                    bottom: false,
                    child: body,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: AppMobileNav(
              current: _current,
              onSelect: _onSelect,
            ),
          );

    return DesktopShellChromeScope(
      controller: _chrome,
      child: ShellTabScope(
        current: _current,
        retapEpoch: _retapEpoch,
        retapDestination: _retapDestination,
        child: PopScope(
          // Nested tab stacks are not visible to the root navigator; handle
          // back here with a live canPop check (build-time canPop would be stale).
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onSystemBack();
          },
          child: scaffold,
        ),
      ),
    );
  }
}
