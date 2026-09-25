import 'dart:convert';

/// Final redaction / scrub / UTF-8 truncate before Memory or File sink.
abstract final class LogRedactor {
  static const maxUtf8Bytes = 2048;

  static const _sensitiveKeyFragments = [
    'cookie',
    'authorization',
    'token',
    'access_token',
    'refresh_token',
    'password',
    'passwd',
    'credential',
    'secret',
    'qr',
    'data',
  ];

  static final _scrubPatterns = <RegExp>[
    RegExp(r'cookie\s*=\s*[^\s;&]+', caseSensitive: false),
    RegExp(r'authorization\s*[:=]\s*[^\s,&]+', caseSensitive: false),
    RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    RegExp(r'token\s*=\s*[^\s;&]+', caseSensitive: false),
    RegExp(r'password\s*=\s*[^\s;&]+', caseSensitive: false),
    RegExp(r'[?&](code|password|token|access_token)=[^&\s]+', caseSensitive: false),
  ];

  /// Redact [fields] in place (returns new map). Never throws to caller — on
  /// failure returns a minimal `{event}`-safe map via [fallbackEvent].
  static Map<String, dynamic> redactFields(
    Map<String, dynamic>? fields, {
    String? fallbackEvent,
  }) {
    try {
      if (fields == null || fields.isEmpty) return {};
      return _redactValue(fields) as Map<String, dynamic>;
    } catch (_) {
      return fallbackEvent == null
          ? <String, dynamic>{}
          : <String, dynamic>{'event': fallbackEvent};
    }
  }

  static String scrubString(String input) {
    var s = input;
    for (final re in _scrubPatterns) {
      s = s.replaceAll(re, '[redacted]');
    }
    return truncateUtf8(s, maxUtf8Bytes);
  }

  static String truncateUtf8(String input, int maxBytes) {
    final units = utf8.encode(input);
    if (units.length <= maxBytes) return input;
    var end = maxBytes;
    // Drop trailing continuation bytes, then any incomplete multi-byte lead.
    while (end > 0 && (units[end - 1] & 0xC0) == 0x80) {
      end--;
    }
    if (end > 0) {
      final b = units[end - 1];
      final need = (b & 0xE0) == 0xC0
          ? 2
          : (b & 0xF0) == 0xE0
              ? 3
              : (b & 0xF8) == 0xF0
                  ? 4
                  : 1;
      if (end - 1 + need > maxBytes) {
        end--;
      }
    }
    return utf8.decode(units.sublist(0, end), allowMalformed: false);
  }

  /// Structured exception fields only — never raw [error.toString()].
  static Map<String, dynamic> exceptionFields({
    required Object error,
    StackTrace? stackTrace,
    int? status,
    String? message,
    String? source,
  }) {
    final fields = <String, dynamic>{
      'errorType': error.runtimeType.toString(),
    };
    if (status != null) fields['status'] = status;
    if (message != null && message.isNotEmpty) {
      fields['message'] = scrubString(message);
    } else {
      fields['message'] = 'unexpected';
    }
    if (stackTrace != null) {
      fields['stack'] = scrubString(stackTrace.toString());
    }
    if (source != null) fields['source'] = source;
    return fields;
  }

  static dynamic _redactValue(dynamic value) {
    if (value is Map) {
      final out = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (_isSensitiveKey(key)) {
          // Drop value entirely for sensitive keys (design: 未知字段默认丢弃值).
          continue;
        }
        out[key] = _redactValue(entry.value);
      }
      final encoded = utf8.encode(jsonEncode(out));
      if (encoded.length > maxUtf8Bytes) {
        return _truncateMap(out);
      }
      return out;
    }
    if (value is List) {
      return value.map(_redactValue).toList();
    }
    if (value is String) {
      return scrubString(value);
    }
    return value;
  }

  static bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    return _sensitiveKeyFragments.contains(lower);
  }

  static Map<String, dynamic> _truncateMap(Map<String, dynamic> map) {
    // Prefer keeping short keys; drop longest string values until under limit.
    final out = Map<String, dynamic>.from(map);
    while (utf8.encode(jsonEncode(out)).length > maxUtf8Bytes && out.isNotEmpty) {
      String? longestKey;
      var longestLen = -1;
      for (final e in out.entries) {
        final len = e.value is String ? (e.value as String).length : 0;
        if (len > longestLen) {
          longestLen = len;
          longestKey = e.key;
        }
      }
      if (longestKey == null || longestLen <= 0) {
        out.remove(out.keys.last);
      } else {
        final s = out[longestKey] as String;
        out[longestKey] = truncateUtf8(s, (s.length / 2).ceil().clamp(1, maxUtf8Bytes));
        if (utf8.encode(jsonEncode(out)).length > maxUtf8Bytes) {
          out.remove(longestKey);
        }
      }
    }
    return out;
  }
}
