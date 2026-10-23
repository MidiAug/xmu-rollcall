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
      throw const FormatException('请输入 HTTPS 节点首页，不含账号、参数或文件路径');
    }
    return uri.replace(path: '/');
  }

  static Future<Uri?> read() async {
    try {
      final value = (await SharedPreferences.getInstance()).getString(key);
      return value == null ? null : parse(value);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = value == null
        ? await prefs.remove(key)
        : await prefs.setString(key, parse(value).toString());
    if (!saved) throw StateError('无法保存下载线路');
  }
}
