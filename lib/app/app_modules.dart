import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_hub_page.dart';
import 'package:xmu_rollcall/features/homework/homework_hub_page.dart';
import 'package:xmu_rollcall/features/settings/settings_page.dart';
import 'package:xmu_rollcall/features/settings/courses_page.dart';
import 'package:xmu_rollcall/features/campus/campus_tools_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';

class AppModule {
  const AppModule({required this.destination, required this.page});
  final AppDestination destination;
  final WidgetBuilder page;
  String get id => destination.id;
}

/// Single registry owns each module's page and its stable navigation identity.
final appModules = <AppModule>[
  AppModule(
    destination: AppDestination.rollcall,
    page: (_) => const RollcallHubPage(),
  ),
  AppModule(
    destination: AppDestination.homework,
    page: (_) => const HomeworkHubPage(),
  ),
  AppModule(
    destination: AppDestination.settings,
    page: (_) => const SettingsPage(),
  ),
  AppModule(
    destination: AppDestination.timetable,
    page: (_) => Consumer(
      builder: (context, ref, _) {
        final scope = ref.watch(selectedRollcallAccountProvider);
        return CoursesPage(key: ValueKey(scope), assistUserId: scope);
      },
    ),
  ),
  AppModule(
    destination: AppDestination.campusTools,
    page: (_) => const CampusToolsPage(),
  ),
];
