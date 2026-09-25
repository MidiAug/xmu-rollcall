import 'dart:convert';

/// One NDJSON diagnostic envelope (post-redaction only).
class LogRecord {
  const LogRecord({
    required this.ts,
    required this.level,
    required this.event,
    this.opId,
    this.fields = const {},
  });

  final DateTime ts;
  final String level;
  final String event;
  final String? opId;
  final Map<String, dynamic> fields;

  String get msg => event;

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'ts': ts.toUtc().toIso8601String(),
      'level': level,
      'event': event,
      'msg': msg,
      'fields': fields,
    };
    if (opId != null && opId!.isNotEmpty) {
      m['opId'] = opId;
    }
    return m;
  }

  String toNdjsonLine() => jsonEncode(toJson());

  static LogRecord? tryParse(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    try {
      final map = jsonDecode(trimmed) as Map<String, dynamic>;
      final event = map['event'] as String?;
      final tsRaw = map['ts'] as String?;
      final level = map['level'] as String?;
      if (event == null || event.isEmpty || tsRaw == null || level == null) {
        return null;
      }
      final ts = DateTime.tryParse(tsRaw);
      if (ts == null) return null;
      final fieldsRaw = map['fields'];
      final fields = fieldsRaw is Map
          ? Map<String, dynamic>.from(fieldsRaw)
          : <String, dynamic>{};
      return LogRecord(
        ts: ts.toUtc(),
        level: level,
        event: event,
        opId: map['opId'] as String?,
        fields: fields,
      );
    } catch (_) {
      return null;
    }
  }

  int? get rollcallId {
    final v = fields['rollcallId'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  bool? get ok {
    final v = fields['ok'];
    if (v is bool) return v;
    return null;
  }

  int? get status {
    final v = fields['status'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  int? get latencyMs {
    final v = fields['latencyMs'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }
}
