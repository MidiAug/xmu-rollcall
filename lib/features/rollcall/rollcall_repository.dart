import 'package:dio/dio.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/features/rollcall/number_code.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

class RollcallRepository {
  RollcallRepository({
    required this.http,
    required this.identity,
  });

  final TronHttpClient http;
  final DeviceIdentity identity;

  Future<List<RollcallItem>> fetchActive() async {
    await http.init();
    final res = await http.getUri<Map<String, dynamic>>(
      TronEndpoints.radarRollcalls(),
    );
    final data = res.data ?? const {};
    final rawList = data['rollcalls'];
    if (rawList is! List) return const [];
    return rawList
        .whereType<Map>()
        .map((e) => RollcallItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// List + for number types, fetch `number_code` (does not affect poll stop).
  Future<List<RollcallItem>> fetchActiveEnriched() async {
    final items = await fetchActive();
    if (items.isEmpty) return items;
    final out = <RollcallItem>[];
    for (final item in items) {
      if (!item.isNumber) {
        out.add(item);
        continue;
      }
      try {
        final code = await fetchNumberCode(item.rollcallId);
        if (code == null || code.isEmpty) {
          out.add(
            item.copyWith(
              numberCodeError: '\u672a\u5728 student_rollcalls \u4e2d\u627e\u5230 number_code',
            ),
          );
        } else {
          out.add(
            item.copyWith(
              numberCode: code,
              clearNumberCodeError: true,
            ),
          );
        }
      } catch (e) {
        out.add(item.copyWith(numberCodeError: '$e'));
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return out;
  }

  Future<String?> fetchNumberCode(int rollcallId) async {
    final res = await http.getUri<dynamic>(
      TronEndpoints.studentRollcalls(rollcallId),
    );
    if ((res.statusCode ?? 0) != 200) {
      throw StateError(
        '\u83b7\u53d6\u7b7e\u5230\u7801\u5931\u8d25 (${res.statusCode})',
      );
    }
    return findNumberCode(res.data);
  }

  /// Course rollcall history (gammars / dashboard style). Serial + gap for KB-01.
  Future<List<CourseRollcallRecord>> fetchCourseHistory({
    required int studentId,
    int maxCourses = 40,
  }) async {
    await http.init();
    final courses = await _probeCourses();
    final out = <CourseRollcallRecord>[];
    var n = 0;
    for (final course in courses) {
      if (n >= maxCourses) break;
      n++;
      final cid = course['id']!;
      final title = course['title']!;
      try {
        final res = await http.getUri<dynamic>(
          TronEndpoints.courseStudentRollcalls(
            courseId: cid,
            studentId: studentId,
          ),
        );
        final rollcalls = _unwrapList(
          res.data,
          const ['rollcalls', 'activities', 'data', 'items', 'list', 'results'],
        );
        if (rollcalls.isEmpty) {
          out.add(
            CourseRollcallRecord(
              courseId: cid,
              courseTitle: title,
              rollcallId: '-',
              rollcallTime: null,
              typeLabel: '-',
              signedStatus: '\u65e0\u7b7e\u5230\u8bb0\u5f55',
              platformStatus: '-',
              detail: '',
            ),
          );
        } else {
          for (final raw in rollcalls) {
            if (raw is! Map) continue;
            final m = Map<String, dynamic>.from(raw);
            out.add(_normalizeCourseRollcall(cid, title, m));
          }
        }
      } catch (e) {
        out.add(
          CourseRollcallRecord(
            courseId: cid,
            courseTitle: title,
            rollcallId: '-',
            rollcallTime: null,
            typeLabel: '-',
            signedStatus: '\u672a\u77e5',
            platformStatus: '-',
            detail: '$e',
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    out.sort((a, b) {
      final at = a.rollcallTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.rollcallTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return out;
  }

  Future<List<Map<String, String>>> _probeCourses() async {
    Object? lastErr;
    for (final path in TronEndpoints.courseListPaths) {
      try {
        final uri = Uri.parse('${TronEndpoints.baseUrl}$path');
        final res = await http.getUri<dynamic>(uri);
        if ((res.statusCode ?? 0) != 200) continue;
        final list = _unwrapList(
          res.data,
          const ['courses', 'data', 'items', 'list', 'results'],
        );
        final courses = <Map<String, String>>[];
        for (final item in list) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          final id = _first(m, const ['id', 'course_id', 'courseId', 'cid']);
          final title = _first(
            m,
            const ['name', 'title', 'course_title', 'course_name', 'display_name'],
          );
          if (id == null || title == null) continue;
          courses.add({'id': id, 'title': title});
        }
        if (courses.isNotEmpty) return courses;
      } catch (e) {
        lastErr = e;
      }
    }
    throw StateError(
      '\u8bfe\u7a0b\u5217\u8868\u63a2\u6d4b\u5931\u8d25${lastErr != null ? ": $lastErr" : ""}',
    );
  }

  List<dynamic> _unwrapList(dynamic payload, List<String> keys) {
    if (payload is List) return payload;
    if (payload is! Map) return const [];
    final map = Map<String, dynamic>.from(payload);
    for (final key in keys) {
      final v = map[key];
      if (v is List) return v;
      if (v is Map) {
        final nested = _unwrapList(v, keys);
        if (nested.isNotEmpty) return nested;
      }
    }
    for (final v in map.values) {
      if (v is Map) {
        final nested = _unwrapList(v, keys);
        if (nested.isNotEmpty) return nested;
      }
    }
    return const [];
  }

  String? _first(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
    }
    return null;
  }

  CourseRollcallRecord _normalizeCourseRollcall(
    String courseId,
    String courseTitle,
    Map<String, dynamic> rollcall,
  ) {
    final id = _first(
          rollcall,
          const ['rollcall_id', 'id', 'activity_id'],
        ) ??
        '-';
    final type = _typeLabel(rollcall);
    final platform = _first(
          rollcall,
          const ['status', 'rollcall_status', 'state'],
        ) ??
        'unknown';
    final signed = _inferSigned(platform, rollcall);
    final timeRaw = _first(
      rollcall,
      const ['rollcall_time', 'created_at', 'start_time', 'time'],
    );
    DateTime? time;
    if (timeRaw != null) {
      time = DateTime.tryParse(timeRaw.replaceFirst('Z', '+00:00'));
    }
    return CourseRollcallRecord(
      courseId: courseId,
      courseTitle: courseTitle,
      rollcallId: id,
      rollcallTime: time,
      typeLabel: type,
      signedStatus: signed,
      platformStatus: platform,
    );
  }

  String _typeLabel(Map<String, dynamic> rollcall) {
    if (rollcall['is_radar'] == true) return '\u96f7\u8fbe';
    if (rollcall['is_number'] == true) return '\u6570\u5b57';
    if (rollcall['is_qrcode'] == true || rollcall['is_qr'] == true) {
      return '\u4e8c\u7ef4\u7801';
    }
    final v = (_first(rollcall, const ['rollcall_type', 'type', 'kind']) ?? '')
        .toLowerCase();
    if (v.contains('radar')) return '\u96f7\u8fbe';
    if (v.contains('number')) return '\u6570\u5b57';
    if (v.contains('qr')) return '\u4e8c\u7ef4\u7801';
    return v.isEmpty ? '\u7b7e\u5230' : v;
  }

  String _inferSigned(String platform, Map<String, dynamic> rollcall) {
    final blob = [
      platform,
      _first(rollcall, const ['student_status']) ?? '',
    ].join(' ').toLowerCase();
    const signed = ['signed', 'present', 'attended', 'on_call_fine', 'fine', 'done'];
    const absent = ['absent', 'missed', 'not_signed', 'unanswered'];
    if (signed.any(blob.contains)) return '\u5df2\u7b7e\u5230';
    if (absent.any(blob.contains)) return '\u672a\u7b7e\u5230';
    return '\u672a\u77e5';
  }

  Future<AnswerResult> answerNumber({
    required int rollcallId,
    required String numberCode,
  }) async {
    final deviceId = await identity.getId();
    final res = await http.putUri<dynamic>(
      TronEndpoints.answerNumber(rollcallId),
      data: {
        'deviceId': deviceId,
        'numberCode': numberCode,
      },
    );
    return _mapAnswer(res);
  }

  Future<AnswerResult> answerRadar({
    required int rollcallId,
    required double latitude,
    required double longitude,
    double accuracy = 35,
  }) async {
    final deviceId = await identity.getId();
    final res = await http.putUri<dynamic>(
      TronEndpoints.answerRadar(rollcallId),
      data: {
        'accuracy': accuracy,
        'altitude': 0,
        'altitudeAccuracy': null,
        'deviceId': deviceId,
        'heading': null,
        'latitude': latitude,
        'longitude': longitude,
        'speed': null,
      },
    );
    return _mapAnswer(res);
  }

  /// Student QR answer: `{ data, deviceId }` (data from scan/paste).
  Future<AnswerResult> answerQr({
    required int rollcallId,
    required String data,
  }) async {
    final deviceId = await identity.getId();
    final res = await http.putUri<dynamic>(
      TronEndpoints.answerQr(rollcallId),
      data: {
        'data': data,
        'deviceId': deviceId,
      },
    );
    return _mapAnswer(res);
  }

  /// Course id set for the current [http] session (assist same-course filter).
  Future<Set<String>> fetchCourseIds() async {
    final courses = await _probeCourses();
    return courses.map((e) => e['id']!).toSet();
  }

  AnswerResult _mapAnswer(Response<dynamic> res) {
    final status = res.statusCode ?? 0;
    final data = res.data;
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{'raw': data};
    if (status >= 200 && status < 300) {
      return AnswerResult(ok: true, message: '提交成功', raw: map);
    }
    final distance = map['distance'];
    final msg = distance != null
        ? '未成功，距离约 $distance'
        : (map['message']?.toString() ?? '提交失败 ($status)');
    return AnswerResult(ok: false, message: msg, raw: map);
  }
}
