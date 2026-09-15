import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/history/history_page.dart';
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

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.shellBreakpoint;
    final pages = const [
      RollcallHubPage(),
      HistoryPage(),
      SettingsPage(),
    ];
    final body = IndexedStack(index: _current.index, children: pages);
    final showTitleBar = PlatformHooks.isDesktop;

    if (wide) {
      return Scaffold(
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
                        onSelect: (d) => setState(() => _current = d),
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
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: p.canvas,
      body: Column(
        children: [
          if (showTitleBar) const AppTitleBar(title: '畅课签到'),
          Expanded(child: SafeArea(bottom: false, child: body)),
        ],
      ),
      bottomNavigationBar: AppMobileNav(
        current: _current,
        onSelect: (d) => setState(() => _current = d),
      ),
    );
  }
}
