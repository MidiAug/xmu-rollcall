import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_brand.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/desktop_shell_chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/app/shell_tab_exit_guard.dart';
import 'package:xmu_rollcall/app/shell_navigation.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account_menu.dart';
import 'package:xmu_rollcall/features/homework/homework_hub_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_hub_page.dart';
import 'package:xmu_rollcall/features/settings/settings_page.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
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
  final _tabExit = ShellTabExitController();
  bool _selecting = false;

  final _navKeys = List<GlobalKey<NavigatorState>>.generate(
    AppDestination.values.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  void initState() {
    super.initState();
    ShellNavigation.instance.bind(_openDestination);
  }

  @override
  void dispose() {
    ShellNavigation.instance.unbind(_openDestination);
    _chrome.dispose();
    super.dispose();
  }

  void _openDestination(AppDestination d, {bool popToRoot = false}) {
    unawaited(_selectDestination(d, resetCurrent: popToRoot));
  }

  void _onSelect(AppDestination d) {
    unawaited(_selectDestination(d, resetCurrent: true));
  }

  void _resetRoutes(AppDestination d) {
    _navKeys[d.index].currentState?.popUntil((route) => route.isFirst);
    _chrome.clearSubpageClaims(d);
  }

  Future<void> _selectDestination(
    AppDestination d, {
    required bool resetCurrent,
  }) async {
    if (!mounted || _selecting || (d == _current && !resetCurrent)) return;
    _selecting = true;
    AppShellSelect.closeAll();
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      if (!await _tabExit.canLeave(context, _current) || !mounted) return;
      _resetRoutes(_current);
      if (d != _current) _resetRoutes(d);
      setState(() {
        _current = d;
        _retapEpoch++;
        _retapDestination = d;
      });
      _chrome.current = d;
    } finally {
      _selecting = false;
    }
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
                if (showTitleBar) const AppTitleBar(title: kAppDisplayName),
                if (showTitleBar) Container(height: 1, color: p.border),
                Expanded(
                  child: Row(
                    children: [
                      Consumer(
                        builder: (context, ref, _) {
                          final name = ref
                              .watch(authControllerProvider)
                              .profile
                              ?.name;
                          final hasUpdate = ref.watch(
                            appUpdateControllerProvider.select(
                              (c) => c.update != null,
                            ),
                          );
                          final auth = ref.watch(authControllerProvider);
                          final roster = ref
                              .watch(assistControllerProvider)
                              .identities;
                          final selected = ref.watch(
                            selectedRollcallAccountProvider,
                          );
                          return AppSidebar(
                            current: _current,
                            onSelect: _onSelect,
                            userLabel: name,
                            accountControl: auth.isSignedIn
                                ? RollcallAccountMenu(
                                    width:
                                        AppLayout.sidebarWidth -
                                        AppSpace.sm * 2,
                                    value:
                                        roster.any((a) => a.userId == selected)
                                        ? selected!
                                        : 0,
                                    identities: roster,
                                    ownerName: name ?? '我',
                                    onChanged: (value) {
                                      // Detail routes are bound to the identity they opened with.
                                      for (final d in [
                                        AppDestination.rollcall,
                                        AppDestination.homework,
                                      ]) {
                                        _navKeys[d.index].currentState
                                            ?.popUntil((r) => r.isFirst);
                                      }
                                      ref
                                          .read(
                                            selectedRollcallAccountProvider
                                                .notifier,
                                          )
                                          .state = value == 0
                                          ? null
                                          : value;
                                    },
                                  )
                                : TextButton.icon(
                                    onPressed: () => showLoginDialog(context),
                                    icon: const Icon(
                                      Icons.person_outline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('登录账号'),
                                  ),
                            hasUpdate: hasUpdate,
                          );
                        },
                      ),
                      Container(width: 1, color: p.border),
                      Expanded(child: AppToastRegion(child: body)),
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
                if (showTitleBar) const AppTitleBar(title: kAppDisplayName),
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
            bottomNavigationBar: Consumer(
              builder: (context, ref, _) => AppMobileNav(
                current: _current,
                onSelect: _onSelect,
                hasUpdate: ref.watch(
                  appUpdateControllerProvider.select((c) => c.update != null),
                ),
              ),
            ),
          );

    return ShellTabExitScope(
      controller: _tabExit,
      child: DesktopShellChromeScope(
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
      ),
    );
  }
}
