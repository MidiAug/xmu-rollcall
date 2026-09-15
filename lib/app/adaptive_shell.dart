import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/history/history_page.dart';
import 'package:xmu_rollcall/features/monitor/monitor_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_list_page.dart';
import 'package:xmu_rollcall/features/settings/settings_page.dart';

class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key});

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  AppDestination _current = AppDestination.rollcall;

  static const _destinations = AppDestination.values;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= AppLayout.shellBreakpoint;

    final pages = [
      const RollcallListPage(),
      const MonitorPage(),
      const HistoryPage(),
      const SettingsPage(),
    ];

    final body = IndexedStack(
      index: _current.index,
      children: pages,
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: width >= 900,
              minExtendedWidth: AppLayout.railExtendedWidth,
              selectedIndex: _current.index,
              onDestinationSelected: (i) {
                setState(() => _current = _destinations[i]);
              },
              labelType: width >= 900
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'xmu-rollcall',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(_icon(d)),
                    selectedIcon: Icon(_icon(d)),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        child: Text(
                          _current.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_current.title)),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _current.index,
        onDestinationSelected: (i) {
          setState(() => _current = _destinations[i]);
        },
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(_icon(d)),
              label: d.label,
            ),
        ],
      ),
    );
  }

  IconData _icon(AppDestination d) => switch (d) {
        AppDestination.rollcall => Icons.how_to_reg_outlined,
        AppDestination.monitor => Icons.radar_outlined,
        AppDestination.history => Icons.history,
        AppDestination.settings => Icons.person_outline,
      };
}
