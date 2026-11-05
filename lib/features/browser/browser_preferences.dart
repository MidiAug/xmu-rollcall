import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

final websiteExternalLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

enum WebsiteOpenMode {
  inApp('本软件'),
  systemBrowser('系统默认浏览器');

  const WebsiteOpenMode(this.label);
  final String label;
}

final websiteOpenModeProvider =
    StateNotifierProvider<WebsiteOpenModeController, WebsiteOpenMode>(
      (ref) => WebsiteOpenModeController(),
    );

class WebsiteOpenModeController extends StateNotifier<WebsiteOpenMode> {
  WebsiteOpenModeController() : super(WebsiteOpenMode.inApp) {
    ready = _load();
  }
  static const key = 'campus_website_open_mode';
  late final Future<void> ready;
  bool _edited = false;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _edited) return;
    state = prefs.getString(key) == WebsiteOpenMode.systemBrowser.name
        ? WebsiteOpenMode.systemBrowser
        : WebsiteOpenMode.inApp;
  }

  Future<void> set(WebsiteOpenMode mode) async {
    _edited = true;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, mode.name);
  }
}
