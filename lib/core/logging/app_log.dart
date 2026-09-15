import 'package:flutter/foundation.dart';

/// Cross-platform log facade (Windows / Android same API).
/// Diagnostics UI can read [recent]; never log passwords.
abstract final class AppLog {
  static const _max = 200;
  static final List<String> _recent = [];
  static bool enabled = false;

  static List<String> get recent => List.unmodifiable(_recent);

  static void clear() => _recent.clear();

  static void d(String message, {String tag = 'app'}) =>
      _add('D', tag, message);

  static void i(String message, {String tag = 'app'}) =>
      _add('I', tag, message);

  static void w(String message, {String tag = 'app'}) =>
      _add('W', tag, message);

  static void e(String message, {String tag = 'app', Object? error}) {
    final suffix = error == null ? '' : ' | $error';
    _add('E', tag, '$message$suffix');
  }

  static void _add(String level, String tag, String message) {
    final line =
        '${DateTime.now().toIso8601String()} [$level][$tag] $message';
    _recent.insert(0, line);
    if (_recent.length > _max) {
      _recent.removeRange(_max, _recent.length);
    }
    if (enabled || kDebugMode) {
      debugPrint(line);
    }
  }
}
