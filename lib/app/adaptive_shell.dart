import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/location/place_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account_menu.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_brand.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/features/campus/campus_search_page.dart';
import 'package:xmu_rollcall/features/homework/homework_badge.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/shell_destination_scope.dart';
import 'package:xmu_rollcall/app/app_modules.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_tab_scope.dart';
import 'package:xmu_rollcall/app/shell_tab_exit_guard.dart';
import 'package:xmu_rollcall/app/shell_navigation.dart';
import 'package:xmu_rollcall/app/retained_tab_viewport.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/login_page.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key});

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  AppDestination _current = AppDestination.rollcall;
  final _visited = <AppDestination>{AppDestination.rollcall};
  int _retapEpoch = 0;
  AppDestination? _retapDestination;

  final _tabExit = ShellTabExitController();
  bool _selecting = false;

  final _navKeys = {
    for (final module in appModules)
      module.destination: GlobalKey<NavigatorState>(),
  };
  final _routeObservers = {
    for (final module in appModules) module.destination: _TabRouteObserver(),
  };

  @override
  void initState() {
    super.initState();
    ShellNavigation.instance.bind(_openDestination);
  }

  @override
  void reassemble() {
    super.reassemble();
    // Handwritten providers have no source hash to invalidate on hot reload.
    // Re-read local snapshots so updated matching rules also refresh badges.
    ProviderScope.containerOf(
      context,
      listen: false,
    ).invalidate(campusCachedDataProvider);
  }

  @override
  void dispose() {
    ShellNavigation.instance.unbind(_openDestination);
    for (final observer in _routeObservers.values) {
      observer.hasSubpage.dispose();
    }
    super.dispose();
  }

  void _openDestination(AppDestination d, {bool popToRoot = false}) {
    unawaited(_selectDestination(d, resetCurrent: popToRoot));
  }

  void _onSelect(AppDestination d) {
    unawaited(_selectDestination(d, resetCurrent: true));
  }

  void _resetRoutes(AppDestination d) {
    _routeObservers[d]?.resetToRoot();
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
        _visited.add(d);
        _current = d;
        _retapEpoch++;
        _retapDestination = d;
      });
    } finally {
      _selecting = false;
    }
  }

  Widget _tabNavigator(AppDestination d, WidgetBuilder page) {
    return ShellTabDestination(
      destination: d,
      child: Navigator(
        key: _navKeys[d]!,
        observers: [_routeObservers[d]!],
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(settings: settings, builder: page);
        },
      ),
    );
  }

  void _onSystemBack() {
    final nav = _navKeys[_current]?.currentState;
    if (nav != null && nav.canPop()) {
      unawaited(nav.maybePop());
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
    final body = Stack(
      fit: StackFit.expand,
      children: [
        for (final module in appModules)
          RetainedTabViewport(
            key: ValueKey(module.destination),
            active: module.destination == _current,
            child: _visited.contains(module.destination)
                ? _tabNavigator(module.destination, module.page)
                : const SizedBox.shrink(),
          ),
      ],
    );
    final showTitleBar = PlatformHooks.isDesktop;

    final scaffold = wide
        ? Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: p.pageBackground(context),
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
                            hasPendingPlace: ref
                                .watch(unmatchedRoomsProvider)
                                .isNotEmpty,
                            current: _current,
                            onSelect: _onSelect,
                            userLabel: name,
                            accountControl: auth.isSignedIn
                                ? RollcallAccountMenu(
                                    sidebar: true,
                                    watchingAccounts: {
                                      for (final entry
                                          in ref
                                              .watch(
                                                accountMonitorStatesProvider,
                                              )
                                              .entries)
                                        if (entry.value.running &&
                                            entry.value.config.courseWatch)
                                          entry.key ?? 0,
                                    },
                                    width:
                                        AppLayout.sidebarWidthOf(context) - 20,
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
                                        _navKeys[d]?.currentState?.popUntil(
                                          (r) => r.isFirst,
                                        );
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
                                    icon: const Icon(AppIcons.person, size: 18),
                                    label: const Text('登录账号'),
                                  ),
                            hasUpdate: hasUpdate,
                          );
                        },
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                          ),
                          child: AppToastRegion(child: body),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: p.pageBackground(context),
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
            bottomNavigationBar: ValueListenableBuilder<bool>(
              valueListenable: _routeObservers[_current]!.hasSubpage,
              builder: (context, hasSubpage, _) =>
                  Theme.of(context).platform == TargetPlatform.android &&
                      hasSubpage
                  ? const SizedBox.shrink()
                  : Consumer(
                      builder: (context, ref, _) => AppMobileNav(
                        current: _current,
                        onSelect: _onSelect,
                        homeworkCount:
                            Theme.of(context).platform == TargetPlatform.android
                            ? ref
                                      .watch(homeworkBadgeCountProvider)
                                      .whenOrNull(
                                        skipLoadingOnReload: false,
                                        data: (count) => count,
                                      ) ??
                                  0
                            : 0,
                        onSearch:
                            Theme.of(context).platform == TargetPlatform.android
                            ? () {
                                AppShellSelect.closeAll();
                                FocusManager.instance.primaryFocus?.unfocus();
                                Navigator.of(context, rootNavigator: true).push(
                                  AppPageRoutes.build(const CampusSearchPage()),
                                );
                              }
                            : null,
                        hasUpdate: ref.watch(
                          appUpdateControllerProvider.select(
                            (c) => c.update != null,
                          ),
                        ),
                      ),
                    ),
            ),
          );

    return ShellTabExitScope(
      controller: _tabExit,
      child: ShellTabScope(
        current: _current,
        hasGlobalIdentityControl: wide,
        retapEpoch: _retapEpoch,
        retapDestination: _retapDestination,
        child: PopScope(
          // Nested tab stacks are not visible to the root navigator; handle
          // back here with a live canPop check (build-time canPop would be stale).
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _onSystemBack();
          },
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: PlatformHooks.isDesktop
                ? (event) {
                    final focus = FocusManager.instance.primaryFocus;
                    final box = focus?.context?.findRenderObject();
                    if (box is RenderBox &&
                        box.attached &&
                        box.hasSize &&
                        !(box.localToGlobal(Offset.zero) & box.size).contains(
                          event.position,
                        )) {
                      focus?.unfocus();
                    }
                  }
                : null,
            child: scaffold,
          ),
        ),
      ),
    );
  }
}

/// Leaving a tab already passed its draft/busy guard. Remove nested routes
/// immediately, rather than starting exit animations that a hidden tab mutes.
class _TabRouteObserver extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];
  final hasSubpage = ValueNotifier<bool>(false);
  void _notify() => hasSubpage.value = _routes.any((route) => !route.isFirst);
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _notify();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _notify();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _notify();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _notify();
  }

  void resetToRoot() {
    for (final route
        in _routes.where((route) => !route.isFirst).toList().reversed) {
      navigator?.removeRoute(route);
    }
  }
}
