import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/homework/homework_hub_page.dart';

import '../test/fixtures/homework_preview.dart';

/// A separate Android preview entrypoint. Never bootstraps a real account.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(
    HomeworkPreviewScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: const bool.fromEnvironment('PREVIEW_DARK')
            ? ThemeMode.dark
            : ThemeMode.light,
        home: Scaffold(
          body: const HomeworkHubPage(),
          bottomNavigationBar: AppMobileNav(
            current: AppDestination.homework,
            onSelect: (_) {},
            onSearch: () {},
          ),
        ),
      ),
    ),
  );
}
