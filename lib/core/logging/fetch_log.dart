import 'package:xmu_rollcall/core/logging/app_log.dart';

/// Shared pattern for list / detail fetch result logs.
abstract final class FetchLog {
  static Future<T> run<T>({
    required String event,
    required Future<T> Function() fetch,
    Map<String, dynamic>? fields,
    String trigger = 'user',

    /// Extra fields derived from the successful value (merged into end event).
    Map<String, dynamic> Function(T value)? resultFields,

    /// Override level for successful end event (default `I`).
    String Function(T value)? successLevel,
    int? Function(T value)? countOf,
  }) async {
    final started = DateTime.now();
    final base = <String, dynamic>{'trigger': trigger, ...?fields};
    AppLog.event(event, fields: base);
    try {
      final value = await fetch();
      final count =
          countOf?.call(value) ??
          switch (value) {
            List list => list.length,
            _ => null,
          };
      final extra = resultFields?.call(value) ?? const <String, dynamic>{};
      final level = successLevel?.call(value) ?? 'I';
      AppLog.event(
        event,
        level: level,
        fields: {
          ...base,
          'ok': true,
          'durationMs': DateTime.now().difference(started).inMilliseconds,
          'count': ?count,
          ...extra,
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
