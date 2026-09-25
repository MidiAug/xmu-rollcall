import 'package:xmu_rollcall/core/logging/app_log.dart';

/// Shared pattern for list / detail fetch result logs.
abstract final class FetchLog {
  static Future<T> run<T>({
    required String event,
    required Future<T> Function() fetch,
    Map<String, dynamic>? fields,
    String trigger = 'user',
  }) async {
    final started = DateTime.now();
    final base = <String, dynamic>{
      'trigger': trigger,
      ...?fields,
    };
    AppLog.event(event, fields: base);
    try {
      final value = await fetch();
      final count = switch (value) {
        List list => list.length,
        _ => null,
      };
      AppLog.event(
        event,
        fields: {
          ...base,
          'ok': true,
          'durationMs': DateTime.now().difference(started).inMilliseconds,
          'count': ?count,
        },
      );
      return value;
    } catch (e) {
      AppLog.event(
        event,
        level: 'W',
        fields: {
          ...base,
          'ok': false,
          'durationMs': DateTime.now().difference(started).inMilliseconds,
          'errorType': e.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }
}
