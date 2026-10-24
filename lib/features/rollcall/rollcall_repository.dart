import 'package:dio/dio.dart';
import 'package:xmu_rollcall/features/monitor/detection_window.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/identity/device_identity.dart';
import 'package:xmu_rollcall/core/logging/rollcall_log.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/http_log_summary.dart';
import 'package:xmu_rollcall/core/network/tron_endpoints.dart';
import 'package:xmu_rollcall/core/network/tron_http_client.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/features/rollcall/number_code.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/rollcall/attendance_count.dart';

class RollcallRepository {
  static const _catalogFields =
      'id,name,course_code,timetables,instructors(id,name),course_attributes(teaching_class_name),department(id,name),semester(id),academic_year(id),academic_year_id,semester_id';
  RollcallRepository({
    required this.http,
    required this.identity,
    this.deviceIdOverride,
    this.requireExplicitDeviceId = false,
    this.loadDetectionWindow,
    this.discoveryClock = DateTime.now,
  });

  final TronHttpClient http;
  final DeviceIdentity identity;
  final Future<DetectionWindow> Function()? loadDetectionWindow;
  final DateTime Function() discoveryClock;

  /// When set (assist identity), used instead of local [DeviceIdentity].
  final String? deviceIdOverride;

  /// Assist sessions must never fall back to the owner install id.
  final bool requireExplicitDeviceId;

  Future<AttendanceCount> fetchAttendanceCount(
    int rollcallId, {
    String? opId,
  }) async {
    await http.init();
    final response = await http.getUri<dynamic>(
      TronEndpoints.studentRollcalls(rollcallId),
      options: Options(extra: {'opId': ?opId, 'rollcallId': rollcallId}),
    );
    return AttendanceCount.parse(response.data, rollcallId: rollcallId);
  }

  Future<String> _deviceId() async {
    final override = deviceIdOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    if (requireExplicitDeviceId) {
      throw StateError('协助身份缺少 deviceId，请重新导入或刷新协助名单');
    }
    return identity.getId();
  }

  Future<List<RollcallItem>> fetchActive({
    CancelToken? cancelToken,
    String? opId,
  }) async {
    if (loadDetectionWindow != null) {
      final window = await loadDetectionWindow!();
      final now = discoveryClock();
      if (!window.allows(now)) {
        throw DetectionWindowClosed(window, now);
      }
    }
    await http.init();
    final res = await http.getUri<Map<String, dynamic>>(
      TronEndpoints.radarRollcalls(),
      options: Options(extra: {'opId': ?opId}),
      cancelToken: cancelToken,
    );
    final data = res.data;
    if (data == null) throw const FormatException('Empty rollcall response');
    final rawList = data['rollcalls'];
    if (rawList is! List || rawList.any((item) => item is! Map)) {
      throw const FormatException('Invalid rollcall list response');
    }
    final items = rawList
        .whereType<Map>()
        .map((e) => RollcallItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    for (final item in items.where(
      (item) => item.type == RollcallType.unknown,
    )) {
      AppLog.event(
        'rollcall.type.unknown',
        level: 'W',
        fields: {
          'rollcallId': item.rollcallId,
          'session': http.sessionKey.storageId,
          'topKeys': item.raw.keys.toList()..sort(),
          'hints': HttpLogSummary.responseSummary({
            'rollcalls': [item.raw],
          }, path: '/api/radar/rollcalls'),
        },
      );
    }
    return items;
  }

  /// List + for number types, fetch `number_code` (does not affect poll stop).
  Future<List<RollcallItem>> fetchActiveEnriched({
    CancelToken? cancelToken,
    Map<int, String> cachedNumberCodes = const {},
  }) async {
    final items = await fetchActive(cancelToken: cancelToken);
    return enrichActive([
      for (final item in items)
        if (item.isNumber &&
            item.numberCode?.isNotEmpty != true &&
            cachedNumberCodes[item.rollcallId]?.isNotEmpty == true)
          item.copyWith(
            numberCode: cachedNumberCodes[item.rollcallId],
            clearNumberCodeError: true,
          )
        else
          item,
    ], cancelToken: cancelToken);
  }

  Future<List<RollcallItem>> enrichActive(
    List<RollcallItem> items, {
    CancelToken? cancelToken,
  }) async {
    if (items.isEmpty) return items;
    final out = <RollcallItem>[];
    for (final item in items) {
      if (!item.isNumber ||
          item.isExpired ||
          item.numberCode?.isNotEmpty == true) {
        out.add(item);
        continue;
      }
      try {
        final code = await fetchNumberCode(
          item.rollcallId,
          cancelToken: cancelToken,
        );
        if (code == null || code.isEmpty) {
          out.add(item.copyWith(numberCodeError: '暂未获取到本次签到码，请刷新或手动输入'));
        } else {
          out.add(item.copyWith(numberCode: code, clearNumberCodeError: true));
        }
      } catch (e) {
        if (cancelToken?.isCancelled == true) rethrow;
        out.add(item.copyWith(numberCodeError: '$e'));
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    return out;
  }

  Future<String?> fetchNumberCode(
    int rollcallId, {
    CancelToken? cancelToken,
    String? opId,
  }) async {
    final options = Options(extra: {'opId': ?opId, 'rollcallId': rollcallId});
    final detailResponse = await http.getUri<dynamic>(
      TronEndpoints.rollcallDetail(rollcallId),
      options: options,
      cancelToken: cancelToken,
    );
    if (detailResponse.statusCode != 200) {
      throw StateError('获取签到详情失败 (${detailResponse.statusCode})');
    }
    final detail = detailResponse.data;
    if (detail is! Map) {
      throw const FormatException('Invalid rollcall detail response');
    }
    final courseId = int.tryParse('${detail['course_id']}');
    final timestamp = detail['rollcall_time'];
    // A timestamp without a zone would use the device's timezone, which can
    // silently query the wrong UTC date. Do not guess a date in that case.
    final rollcallTime =
        timestamp is String &&
            RegExp(r'(?:[zZ]|[+-]\d{2}:?\d{2})$').hasMatch(timestamp)
        ? DateTime.tryParse(timestamp)
        : null;
    if (courseId == null || courseId <= 0 || rollcallTime == null) {
      throw const FormatException('Invalid rollcall course or timestamp');
    }
    final res = await http.getUri<dynamic>(
      TronEndpoints.timetableRollcalls(
        courseId: courseId,
        rollcallTime: rollcallTime,
      ),
      options: options,
      cancelToken: cancelToken,
    );
    if ((res.statusCode ?? 0) != 200) {
      throw StateError(
        '\u83b7\u53d6\u7b7e\u5230\u7801\u5931\u8d25 (${res.statusCode})',
      );
    }
    return findTimetableNumberCode(res.data, rollcallId: rollcallId);
  }

  /// Single-course student rollcalls (for session prior; KB-01: one request).
  Future<List<CourseRollcallRecord>> fetchCourseRollcalls({
    required Object courseId,
    required int studentId,
    String courseTitle = '',
  }) async {
    await http.init();
    final cid = '$courseId'.trim();
    final res = await http.getUri<dynamic>(
      TronEndpoints.courseStudentRollcalls(courseId: cid, studentId: studentId),
      priority: RequestPriority.background,
    );
    final rollcalls = _unwrapList(res.data, const [
      'rollcalls',
      'activities',
      'data',
      'items',
      'list',
      'results',
    ]);
    if (rollcalls.isEmpty) return const [];
    final out = <CourseRollcallRecord>[];
    for (final raw in rollcalls) {
      if (raw is! Map) continue;
      out.add(
        _normalizeCourseRollcall(
          cid,
          courseTitle,
          Map<String, dynamic>.from(raw),
        ),
      );
    }
    out.sort((a, b) {
      final at = a.rollcallTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.rollcallTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });
    return out;
  }

  /// Sticky CourseCatalog: courses + timetables (+ optional semester ids).
  Future<CourseCatalogSnapshot> fetchCourseCatalog() async {
    await http.init();
    try {
      final res = await http.postUri<dynamic>(
        TronEndpoints.myCourses(),
        options: Options(extra: const {'retrySafe': true}),
        priority: RequestPriority.background,
        data: const {
          'fields': _catalogFields,
          'conditions': {
            'classify_type': 'recently_started',
            'role': [
              'student',
              'student_assistant',
              'instructor',
              'instructor_assistant',
            ],
            'status': ['ongoing', 'not_started'],
          },
        },
      );
      final parsed = _catalogFromPayload(res.data);
      if (parsed.courses.isNotEmpty) return _resolveCatalogRoles(parsed);
    } catch (_) {
      // fall through
    }
    return _resolveCatalogRoles(await _catalogFromGetProbe());
  }

  Future<CourseCatalogSnapshot> _resolveCatalogRoles(
    CourseCatalogSnapshot catalog,
  ) async {
    try {
      Future<Set<String>> memberships(List<String> roles) async {
        final response = await http.postUri<dynamic>(
          TronEndpoints.myCourses(),
          options: Options(extra: const {'retrySafe': true}),
          priority: RequestPriority.background,
          data: {
            'fields': _catalogFields,
            'conditions': {
              'classify_type': 'recently_started',
              'role': roles,
              'status': ['ongoing', 'not_started'],
            },
          },
        );
        Object? payload = response.data;
        if (payload is Map && payload['data'] is Map) payload = payload['data'];
        final supported =
            payload is List ||
            (payload is Map &&
                (payload.isEmpty ||
                    const [
                      'courses',
                      'data',
                      'items',
                      'list',
                      'results',
                    ].any((key) => (payload as Map)[key] is List)));
        AppLog.event(
          'course_catalog.role_response',
          fields: {
            'roles': roles,
            'status': response.statusCode,
            'dataType': response.data.runtimeType.toString(),
            if (payload is Map) 'topKeys': payload.keys.toList(),
          },
        );
        if (response.statusCode != 200 || !supported) {
          throw const FormatException('课程身份暂不可用');
        }
        final rows = _unwrapList(payload, const [
          'courses',
          'data',
          'items',
          'list',
          'results',
        ]);
        return {
          for (final row in rows)
            if (row is Map && row['id'] != null) '${row['id']}',
        };
      }

      final assistants = await memberships([
        'student_assistant',
        'instructor_assistant',
      ]);
      final instructors = await memberships(['instructor']);
      final courses = [
        for (final c in catalog.courses)
          c.withRoles([
            if (assistants.contains(c.id)) 'instructor_assistant',
            if (instructors.contains(c.id)) 'instructor',
            if (!assistants.contains(c.id) && !instructors.contains(c.id))
              'student',
          ]),
      ];
      AppLog.event(
        'course_catalog.roles',
        fields: {
          'courses': courses.length,
          'assistants': courses.where((c) => c.isTeachingAssistant).length,
          'instructors': courses.where((c) => c.isInstructor).length,
          'teachingIds': [
            for (final c in courses)
              if (c.isTeaching) c.id,
          ],
        },
      );
      return CourseCatalogSnapshot(
        fetchedAt: catalog.fetchedAt,
        courses: courses,
        semesterId: catalog.semesterId,
        academicYearId: catalog.academicYearId,
        rolesResolved: true,
      );
    } catch (error) {
      AppLog.event(
        'course_catalog.roles.failed',
        level: 'W',
        fields: {'errorType': error.runtimeType.toString()},
      );
      return catalog;
    }
  }

  /// Per-course weekday → slots (prefers [fetchCourseCatalog]).
  Future<Map<String, Map<int, List<TimetableSlot>>>>
  fetchCourseTimetables() async {
    final snap = await fetchCourseCatalog();
    return snap.timetablesByCourse;
  }

  CourseCatalogSnapshot _catalogFromPayload(dynamic data) {
    final list = _unwrapList(data, const [
      'courses',
      'data',
      'items',
      'list',
      'results',
    ]);
    final courses = <CatalogCourse>[];
    String? semesterId;
    String? academicYearId;
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final id = _first(m, const ['id', 'course_id', 'courseId', 'cid']);
      final title = _first(m, const [
        'name',
        'title',
        'course_title',
        'course_name',
        'display_name',
      ]);
      if (id == null) continue;
      courses.add(
        CatalogCourse(
          id: id,
          title: title ?? '',
          timetables: parseTimetables(m['timetables']),
          instructorNames: _instructorNames(m),
          teachingClassName: _teachingClassName(m),
          location: _courseLocation(m),
          roles: parseCourseRoles(m['roles'] ?? m['course_role'] ?? m['role']),
        ),
      );
      semesterId ??= _nestedId(m, const ['semester_id', 'semester']);
      academicYearId ??= _nestedId(m, const [
        'academic_year_id',
        'academic_year',
      ]);
    }
    return CourseCatalogSnapshot(
      fetchedAt: DateTime.now(),
      courses: courses,
      semesterId: semesterId,
      academicYearId: academicYearId,
    );
  }

  Future<CourseCatalogSnapshot> _catalogFromGetProbe() async {
    final courses = <CatalogCourse>[];
    for (final path in TronEndpoints.courseListPaths) {
      try {
        final uri = Uri.parse('${TronEndpoints.baseUrl}$path');
        final res = await http.getUri<dynamic>(uri);
        if ((res.statusCode ?? 0) != 200) continue;
        final parsed = _catalogFromPayload(res.data);
        if (parsed.courses.isNotEmpty) return parsed;
      } catch (_) {
        // try next
      }
    }
    if (courses.isEmpty) {
      // Last resort: id/title only via legacy probe.
      final probed = await _probeCourses();
      return CourseCatalogSnapshot(
        fetchedAt: DateTime.now(),
        courses: [
          for (final e in probed)
            CatalogCourse(id: e['id']!, title: e['title'] ?? ''),
        ],
      );
    }
    return CourseCatalogSnapshot(fetchedAt: DateTime.now(), courses: courses);
  }

  String? _nestedId(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is Map) {
        final id = _first(Map<String, dynamic>.from(v), const ['id']);
        if (id != null) return id;
      } else {
        final s = '$v'.trim();
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  List<String> _instructorNames(Map<String, dynamic> m) {
    final raw = m['instructors'];
    if (raw is! List) return const [];
    final names = <String>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final n = e['name'];
      if (n is String && n.trim().isNotEmpty) names.add(n.trim());
    }
    return names;
  }

  String? _teachingClassName(Map<String, dynamic> m) {
    final attrs = m['course_attributes'];
    if (attrs is Map) {
      final n = attrs['teaching_class_name'];
      if (n is String && n.trim().isNotEmpty) return n.trim();
    }
    return null;
  }

  String? _courseLocation(Map<String, dynamic> m) {
    for (final k in const ['classroom', 'location', 'place']) {
      final v = m[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final schedule = m['classroom_schedule'];
    if (schedule is String && schedule.trim().isNotEmpty) {
      return schedule.trim();
    }
    return null;
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
        final rollcalls = _unwrapList(res.data, const [
          'rollcalls',
          'activities',
          'data',
          'items',
          'list',
          'results',
        ]);
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
      await Future<void>.delayed(const Duration(milliseconds: 250));
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
        final list = _unwrapList(res.data, const [
          'courses',
          'data',
          'items',
          'list',
          'results',
        ]);
        final courses = <Map<String, String>>[];
        for (final item in list) {
          if (item is! Map) continue;
          final m = Map<String, dynamic>.from(item);
          final id = _first(m, const ['id', 'course_id', 'courseId', 'cid']);
          final title = _first(m, const [
            'name',
            'title',
            'course_title',
            'course_name',
            'display_name',
          ]);
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
    final id =
        _first(rollcall, const ['rollcall_id', 'id', 'activity_id']) ?? '-';
    final type = _typeLabel(rollcall);
    final platform =
        _first(rollcall, const ['status', 'rollcall_status', 'state']) ??
        'unknown';
    final signed = _inferSigned(platform, rollcall);
    final timeRaw = _first(rollcall, const [
      'rollcall_time',
      'created_at',
      'start_time',
      'time',
    ]);
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
    final statuses = [
      platform,
      _first(rollcall, const ['student_status']) ?? '',
    ].map((value) => value.trim().toLowerCase()).toSet();
    const signed = [
      'signed',
      'present',
      'attended',
      'on_call_fine',
      'fine',
      'done',
    ];
    const absent = [
      'absent',
      'missed',
      'not_signed',
      'unsigned',
      'unanswered',
      'on_call_absence',
    ];
    if (absent.any(statuses.contains)) return '\u672a\u7b7e\u5230';
    if (signed.any(statuses.contains)) return '\u5df2\u7b7e\u5230';
    return '\u672a\u77e5';
  }

  Future<AnswerResult> answerNumber({
    required int rollcallId,
    required String numberCode,
    String? opId,
  }) async {
    final deviceId = await _deviceId();
    final opts = Options(extra: {'opId': ?opId, 'rollcallId': rollcallId});
    final res = await http.putUri<dynamic>(
      TronEndpoints.answerNumber(rollcallId),
      data: {'deviceId': deviceId, 'numberCode': numberCode},
      options: opts,
    );
    return _mapAnswer(res, opId: opId, rollcallId: rollcallId);
  }

  Future<AnswerResult> answerRadar({
    required int rollcallId,
    required double latitude,
    required double longitude,
    double accuracy = 35,
    String? opId,
  }) async {
    if (rollcallId <= 0 ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180 ||
        !accuracy.isFinite ||
        accuracy <= 0) {
      throw ArgumentError('雷达签到的位置或精度无效，请重新选择位置');
    }
    final deviceId = await _deviceId();
    final opts = Options(extra: {'opId': ?opId, 'rollcallId': rollcallId});
    late final Response<dynamic> res;
    try {
      res = await http.putUri<dynamic>(
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
        options: opts,
      );
    } on DioException catch (error) {
      final response = error.response;
      final status = response?.statusCode ?? 0;
      // Business rejections may include the server's distance/message. Keep
      // authentication, throttling and server/transport failures as exceptions.
      if (response == null ||
          status < 400 ||
          status >= 500 ||
          status == 401 ||
          status == 403 ||
          status == 429 ||
          response.data is! Map) {
        rethrow;
      }
      return _mapAnswer(response, opId: opId, rollcallId: rollcallId);
    }
    return _mapAnswer(res, opId: opId, rollcallId: rollcallId);
  }

  /// Student QR answer: `{ data, deviceId }` (data from scan/paste).
  Future<AnswerResult> answerQr({
    required int rollcallId,
    required String data,
    String? deviceId,
    String? opId,
  }) async {
    final id = (deviceId != null && deviceId.trim().isNotEmpty)
        ? deviceId.trim()
        : await _deviceId();
    final opts = Options(extra: {'opId': ?opId, 'rollcallId': rollcallId});
    final res = await http.putUri<dynamic>(
      TronEndpoints.answerQr(rollcallId),
      data: {'data': data, 'deviceId': id},
      options: opts,
    );
    return _mapAnswer(res, opId: opId, rollcallId: rollcallId);
  }

  /// Course id set for the current [http] session (assist same-course filter).
  Future<Set<String>> fetchCourseIds() async {
    final courses = await fetchCourses();
    return courses.map((e) => e.id).toSet();
  }

  /// Course catalog for shared-course intersection (import-time cache).
  Future<List<AssistSharedCourse>> fetchCourses() async {
    final courses = await _probeCourses();
    return [
      for (final e in courses)
        AssistSharedCourse(id: e['id']!, title: e['title'] ?? ''),
    ];
  }

  AnswerResult _mapAnswer(
    Response<dynamic> res, {
    String? opId,
    int? rollcallId,
  }) {
    final status = res.statusCode ?? 0;
    final data = res.data;
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{'raw': data};
    AnswerResult result;
    if (status >= 200 && status < 300) {
      result = AnswerResult(
        ok: true,
        message: '提交成功',
        raw: map,
        status: status,
      );
    } else {
      // Distance is optional legacy data; current XMU rejects may omit it.
      final distance =
          map['distance'] is num && (map['distance'] as num).isFinite
          ? map['distance']
          : null;
      final msg = distance != null
          ? '未成功，距离约 $distance'
          : (map['message']?.toString() ?? '提交失败 ($status)');
      result = AnswerResult(ok: false, message: msg, raw: map, status: status);
    }
    if (opId != null && rollcallId != null) {
      RollcallLog.result(
        opId: opId,
        rollcallId: rollcallId,
        ok: result.ok,
        status: status,
        message: result.message,
        distance: map['distance'],
      );
    }
    return result;
  }
}
