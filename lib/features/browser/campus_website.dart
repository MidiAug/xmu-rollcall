import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'browser_preferences.dart';
import 'campus_web_page.dart';

Future<void> openCampusWebsite(
  BuildContext context, {
  required String title,
  required Uri url,
}) async {
  final container = ProviderScope.containerOf(context);
  final prefs = container.read(websiteOpenModeProvider.notifier);
  await prefs.ready;
  if (!context.mounted) return;
  if (Platform.isWindows &&
      container.read(websiteOpenModeProvider) == WebsiteOpenMode.inApp) {
    AppShellSelect.closeAll();
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => CampusWebPage(title: title, url: url),
      ),
    );
    return;
  }
  try {
    if (await container.read(websiteExternalLauncherProvider)(url)) return;
  } catch (_) {}
  if (context.mounted) AppToast.show(context, '无法打开网页');
}
