import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:xmu_rollcall/core/logging/log_redactor.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

/// Path-aware HTTP body projections for diagnostic export (denylist_v1).
///
/// Never invents `[omit]` placeholders. Unknown APIs return metadata-only
/// (caller supplies method/path/status); body summary may be null.
abstract final class HttpLogSummary {
  static const maxItems = 20;
  static const maxSampleIds = 5;

  static const _queryAllow = {
    'api_version',
    'page',
    'page_size',
    'per_page',
    'course_ids',
    'rollcall_date',
  };

  /// Whether this request should emit http.* events.
  static bool shouldLog({
    required String path,
    String? opId,
    String method = 'GET',
  }) {
    if (opId != null && opId.isNotEmpty) return true;
    return classify(path) != HttpLogKind.none;
  }

  static HttpLogKind classify(String path) {
    if (path.contains('answer_number_rollcall') ||
        path.contains('answer_qr_rollcall') ||
        (path.contains('/api/rollcall/') && path.endsWith('/answer'))) {
      return HttpLogKind.answer;
    }
    if (path.contains('student_rollcalls')) return HttpLogKind.studentRollcalls;
    if (RegExp(r'/api/rollcall/\d+$').hasMatch(path)) {
      return HttpLogKind.rollcallDetail;
    }
    if (path.endsWith('/api/timetable_rollcalls')) {
      return HttpLogKind.timetableRollcalls;
    }
    if (path.contains('/api/radar/rollcalls')) return HttpLogKind.radarList;
    if (path.endsWith('/api/todos') || path.contains('/api/todos?')) {
      return HttpLogKind.todos;
    }
    if (path.contains('homework-activities')) return HttpLogKind.homeworkList;
    return HttpLogKind.none;
  }

  static Map<String, dynamic> filterQuery(Uri uri) {
    final out = <String, dynamic>{};
    uri.queryParameters.forEach((k, v) {
      if (_queryAllow.contains(k)) out[k] = v;
    });
    return out;
  }

  static Map<String, dynamic>? requestSummary(Object? data) {
    if (data == null) return null;
    Map<String, dynamic>? map;
    if (data is Map) {
      map = Map<String, dynamic>.from(data);
    } else if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) map = Map<String, dynamic>.from(decoded);
      } catch (_) {
        return {'len': data.length};
      }
    }
    if (map == null) return null;
    final out = <String, dynamic>{};
    if (map['deviceId'] is String) {
      final id = map['deviceId'] as String;
      out['deviceIdSuffix'] = id.length <= 6 ? id : id.substring(id.length - 6);
    }
    if (map['numberCode'] != null) out['numberCode'] = map['numberCode'];
    if (map['accuracy'] != null) out['accuracy'] = map['accuracy'];
    if (map['latitude'] is num) {
      out['latitude'] = double.parse(
        (map['latitude'] as num).toStringAsFixed(5),
      );
    }
    if (map['longitude'] is num) {
      out['longitude'] = double.parse(
        (map['longitude'] as num).toStringAsFixed(5),
      );
    }
    if (map['data'] is String) {
      final raw = map['data'] as String;
      out['payloadLen'] = raw.length;
      out['payloadSha256Prefix'] = sha256
          .convert(utf8.encode(raw))
          .toString()
          .substring(0, 8);
    }
    return out.isEmpty ? null : out;
  }

  static Map<String, dynamic>? responseSummary(
    Object? data, {
    required String path,
  }) {
    final kind = classify(path);
    return switch (kind) {
      HttpLogKind.radarList => _radarList(data),
      HttpLogKind.studentRollcalls => _studentRollcalls(data),
      HttpLogKind.rollcallDetail => _rollcallDetail(data),
      HttpLogKind.timetableRollcalls => _timetableRollcalls(data),
      HttpLogKind.todos => _todos(data),
      HttpLogKind.homeworkList => _homeworkList(data),
      HttpLogKind.answer => _answerResponse(data),
      HttpLogKind.none => null,
    };
  }

  static Map<String, dynamic>? _radarList(Object? data) {
    final map = _asMap(data);
    final list = _listUnder(map, const ['rollcalls']);
    if (list == null && map == null) return null;
    final items = <Map<String, dynamic>>[];
    var truncated = false;
    for (final raw in list ?? const []) {
      if (raw is! Map) continue;
      if (items.length >= maxItems) {
        truncated = true;
        break;
      }
      items.add(_rollcallItemProjection(Map<String, dynamic>.from(raw)));
    }
    return {
      'itemCount': list?.length ?? 0,
      'items': items,
      if (truncated) 'truncated': true,
    };
  }

  static Map<String, dynamic>? _studentRollcalls(Object? data) {
    final map = _asMap(data);
    if (map == null) return null;
    final nested = map['student_rollcalls'];
    final nestedCount = nested is List ? nested.length : null;
    final numberCode = map['number_code'];
    final hasCode = numberCode != null && '$numberCode'.trim().isNotEmpty;
    return {
      if (map['status'] != null) 'status': map['status'],
      if (map['type'] != null) 'type': map['type'],
      if (map.containsKey('is_number')) 'is_number': map['is_number'] == true,
      if (map.containsKey('is_radar')) 'is_radar': map['is_radar'] == true,
      if (map.containsKey('is_qrcode')) 'is_qrcode': map['is_qrcode'] == true,
      if (map.containsKey('is_qr')) 'is_qr': map['is_qr'] == true,
      'hasNumberCode': hasCode,
      if (hasCode) 'numberCode': numberCode,
      'studentRollcallCount': ?nestedCount,
    };
  }

  static Map<String, dynamic>? _rollcallDetail(Object? data) {
    final map = _asMap(data);
    if (map == null) return null;
    return {
      for (final key in ['id', 'course_id', 'rollcall_time', 'status'])
        if (map.containsKey(key)) key: map[key],
    };
  }

  static Map<String, dynamic>? _timetableRollcalls(Object? data) {
    final map = _asMap(data);
    if (map == null) return null;
    final rows = _listUnder(map, const ['rollcalls']);
    return {
      'hasRollcallsList': rows != null,
      'itemCount': rows?.length ?? 0,
      'items': [
        for (final row in (rows ?? const []).take(maxItems))
          if (row is Map)
            {
              for (final key in ['id', 'course_id', 'status', 'end_time'])
                if (row.containsKey(key)) key: row[key],
              'hasNumberCode':
                  row['number_code'] != null &&
                  '${row['number_code']}'.trim().isNotEmpty,
            },
      ],
      if ((rows?.length ?? 0) > maxItems) 'truncated': true,
    };
  }

  static Map<String, dynamic>? _todos(Object? data) {
    final map = _asMap(data);
    if (map == null) {
      if (data is List) {
        return {
          'topKeys': <String>[],
          'listKeyHit': '(root_list)',
          'count': data.length,
          'sampleIds': _sampleIds(data),
        };
      }
      return null;
    }
    final topKeys = map.keys.map((k) => k.toString()).toList()..sort();
    const candidates = [
      'todo_list',
      'todos',
      'data',
      'items',
      'list',
      'results',
    ];
    String? hit;
    List? list;
    for (final k in candidates) {
      final v = map[k];
      if (v is List) {
        hit = k;
        list = v;
        break;
      }
    }
    return {
      'topKeys': topKeys,
      'listKeyHit': hit,
      'count': list?.length ?? 0,
      if (list != null) 'sampleIds': _sampleIds(list),
    };
  }

  static Map<String, dynamic>? _homeworkList(Object? data) {
    final map = _asMap(data);
    if (map == null) return data is List ? {'count': data.length} : null;
    const candidates = [
      'homework_activities',
      'activities',
      'data',
      'items',
      'list',
      'results',
    ];
    String? hit;
    List? list;
    for (final k in candidates) {
      final v = map[k];
      if (v is List) {
        hit = k;
        list = v;
        break;
      }
    }
    return {
      'topKeys': (map.keys.map((k) => k.toString()).toList()..sort()),
      'listKeyHit': hit,
      'count': list?.length ?? 0,
    };
  }

  static Map<String, dynamic>? _answerResponse(Object? data) {
    final map = _asMap(data);
    if (map == null) return null;
    final out = <String, dynamic>{};
    for (final key in [
      'message',
      'distance',
      'status',
      'error',
      'code',
      'ok',
    ]) {
      if (map.containsKey(key)) out[key] = map[key];
    }
    return out.isEmpty ? null : out;
  }

  static Map<String, dynamic> _rollcallItemProjection(Map<String, dynamic> d) {
    final id = d['rollcall_id'] ?? d['id'];
    return {
      if (id != null) 'rollcallId': id is num ? id.toInt() : id,
      if (d['course_id'] != null) 'courseId': d['course_id'],
      if (d['course_title'] != null) 'courseTitle': d['course_title'],
      if (d.containsKey('is_number')) 'is_number': d['is_number'] == true,
      if (d.containsKey('is_radar')) 'is_radar': d['is_radar'] == true,
      if (d.containsKey('is_qrcode')) 'is_qrcode': d['is_qrcode'] == true,
      if (d.containsKey('is_qr')) 'is_qr': d['is_qr'] == true,
      if (d['type'] != null) 'type': d['type'],
      if (d['source'] != null) 'source': d['source'],
      if (d['rollcall_type'] != null) 'rollcall_type': d['rollcall_type'],
      if (d.containsKey('is_qr_code')) 'is_qr_code': d['is_qr_code'],
      'parsedType': resolveRollcallType(d).name,
      if (d['status'] != null) 'status': d['status'],
      if (d['rollcall_status'] != null) 'rollcall_status': d['rollcall_status'],
      if (d.containsKey('is_expired')) 'is_expired': d['is_expired'] == true,
    };
  }

  static List<dynamic> _sampleIds(List list) {
    final out = <dynamic>[];
    for (final raw in list) {
      if (out.length >= maxSampleIds) break;
      if (raw is! Map) continue;
      final id = raw['id'] ?? raw['activity_id'] ?? raw['rollcall_id'];
      if (id != null) out.add(id);
    }
    return out;
  }

  static Map<String, dynamic>? _asMap(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  static List? _listUnder(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final k in keys) {
      final v = map[k];
      if (v is List) return v;
    }
    return null;
  }

  /// Clamp projection map under projection byte budget (after construction).
  static Map<String, dynamic> clampProjection(Map<String, dynamic> fields) {
    return LogRedactor.redactFields(
      fields,
      maxBytes: LogRedactor.maxProjectionUtf8Bytes,
    );
  }
}

enum HttpLogKind {
  none,
  answer,
  studentRollcalls,
  rollcallDetail,
  timetableRollcalls,
  radarList,
  todos,
  homeworkList,
}
