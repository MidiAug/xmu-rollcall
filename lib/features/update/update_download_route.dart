import 'package:shared_preferences/shared_preferences.dart';

/// Only public package downloads use mirrors. Metadata remains on GitHub.
abstract final class UpdateDownloadRoute {
  static const key = 'update_download_mirror_v1';
  static const suggested = ['https://gh-proxy.com/', 'https://ghproxy.net/'];

  static Uri parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !RegExp(
          r'^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$',
        ).hasMatch(uri.host) ||
        uri.host.endsWith('.local') ||
        uri.host.endsWith('.localhost')) {
      throw const FormatException('请选择内置下载线路');
    }
    final normalized = uri.replace(path: '/');
    if (!suggested.contains(normalized.toString())) {
      throw const FormatException('请选择内置下载线路');
    }
    return normalized;
  }

  static Future<Uri?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('update_download_custom_mirror_v1')) {
        await prefs.remove('update_download_custom_mirror_v1');
      }
      final value = prefs.getString(key);
      if (value == null) return null;
      try {
        return parse(value);
      } on FormatException {
        // Older releases allowed arbitrary custom nodes; fall back before any download.
        await prefs.remove(key);
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final route = value == null ? null : parse(value).toString();
    final saved = value == null
        ? await prefs.remove(key)
        : await prefs.setString(key, route!);
    if (!saved) throw StateError('无法保存下载线路');
  }
}
