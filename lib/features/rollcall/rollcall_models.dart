enum RollcallType { number, radar, qrcode, unknown }

RollcallType resolveRollcallType(Map<String, dynamic> data) {
  bool enabled(String key) =>
      data[key] == true || data[key] == 1 || data[key] == 'true';
  if (enabled('is_radar')) return RollcallType.radar;
  if (enabled('is_number')) return RollcallType.number;
  if (enabled('is_qrcode') || enabled('is_qr') || enabled('is_qr_code')) {
    return RollcallType.qrcode;
  }
  for (final key in ['type', 'source', 'rollcall_type']) {
    final value = '${data[key] ?? ''}'.trim().toLowerCase().replaceAll(
      '-',
      '_',
    );
    if (const {
      'qr',
      'qrcode',
      'qr_code',
      'qr_rollcall',
      'qrcode_rollcall',
      'qr_code_rollcall',
    }.contains(value)) {
      return RollcallType.qrcode;
    }
    if (const {'radar', 'radar_rollcall'}.contains(value)) {
      return RollcallType.radar;
    }
    if (const {'number', 'number_rollcall'}.contains(value)) {
      return RollcallType.number;
    }
  }
  return RollcallType.unknown;
}

class RollcallItem {
  const RollcallItem({
    required this.rollcallId,
    required this.courseTitle,
    required this.createdByName,
    required this.type,
    required this.status,
    required this.rollcallStatus,
    required this.isExpired,
    required this.scored,
    this.departmentName = '',
    this.raw = const {},
    this.numberCode,
    this.numberCodeError,
  });

  final int rollcallId;
  final String courseTitle;
  final String createdByName;
  final String departmentName;
  final RollcallType type;
  final String status;
  final String rollcallStatus;
  final bool isExpired;
  final bool scored;
  final Map<String, dynamic> raw;

  /// Populated for [RollcallType.number] after the timetable rollcall fetch.
  final String? numberCode;

  /// Set when number fetch failed or field missing.
  final String? numberCodeError;

  bool get isAnswered => status == 'on_call_fine';

  bool get isNumber => type == RollcallType.number;
  bool get isRadar => type == RollcallType.radar;
  bool get isQrcode => type == RollcallType.qrcode;

  Map<String, dynamic> toMonitorJson() => {
    ...raw,
    'rollcall_id': rollcallId,
    'course_title': courseTitle,
    'created_by_name': createdByName,
    'department_name': departmentName,
    'is_number': isNumber,
    'is_radar': isRadar,
    'is_qrcode': isQrcode,
    'status': status,
    'rollcall_status': rollcallStatus,
    'is_expired': isExpired,
    'scored': scored,
    'cachedNumberCode': isNumber ? numberCode : null,
  };

  /// Best-effort course id from list payload (for assist same-course filter).
  String? get courseId {
    for (final k in const [
      'course_id',
      'courseId',
      'cid',
      'teaching_unit_id',
    ]) {
      final v = raw[k];
      if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
    }
    return null;
  }

  String get typeLabel => switch (type) {
    RollcallType.number => '数字',
    RollcallType.radar => '雷达',
    RollcallType.qrcode => '二维码',
    RollcallType.unknown => '未知',
  };

  RollcallItem copyWith({
    String? status,
    String? numberCode,
    String? numberCodeError,
    bool clearNumberCode = false,
    bool clearNumberCodeError = false,
  }) {
    return RollcallItem(
      rollcallId: rollcallId,
      courseTitle: courseTitle,
      createdByName: createdByName,
      departmentName: departmentName,
      type: type,
      status: status ?? this.status,
      rollcallStatus: rollcallStatus,
      isExpired: isExpired,
      scored: scored,
      raw: raw,
      numberCode: clearNumberCode ? null : (numberCode ?? this.numberCode),
      numberCodeError: clearNumberCodeError
          ? null
          : (numberCodeError ?? this.numberCodeError),
    );
  }

  factory RollcallItem.fromJson(Map<String, dynamic> d) {
    final type = resolveRollcallType(d);

    return RollcallItem(
      rollcallId: (d['rollcall_id'] as num).toInt(),
      courseTitle: (d['course_title'] as String?) ?? '',
      createdByName: (d['created_by_name'] as String?) ?? '',
      departmentName: (d['department_name'] as String?) ?? '',
      type: type,
      status: (d['status'] as String?) ?? '',
      rollcallStatus: (d['rollcall_status'] as String?) ?? '',
      isExpired: d['is_expired'] == true,
      scored: d['scored'] == true,
      raw: d,
      numberCode: type == RollcallType.number && d['cachedNumberCode'] is String
          ? d['cachedNumberCode'] as String
          : null,
    );
  }
}

class AnswerResult {
  const AnswerResult({
    required this.ok,
    this.message,
    this.raw = const {},
    this.status,
  });

  final bool ok;
  final String? message;
  final Map<String, dynamic> raw;
  final int? status;
}

class RollcallHistoryEntry {
  const RollcallHistoryEntry({
    required this.rollcallId,
    required this.courseTitle,
    required this.typeLabel,
    required this.ok,
    required this.at,
    this.detail,
  });

  final int rollcallId;
  final String courseTitle;
  final String typeLabel;
  final bool ok;
  final DateTime at;
  final String? detail;

  Map<String, dynamic> toJson() => {
    'rollcallId': rollcallId,
    'courseTitle': courseTitle,
    'typeLabel': typeLabel,
    'ok': ok,
    'at': at.toIso8601String(),
    'detail': detail,
  };

  factory RollcallHistoryEntry.fromJson(Map<String, dynamic> j) {
    return RollcallHistoryEntry(
      rollcallId: (j['rollcallId'] as num).toInt(),
      courseTitle: j['courseTitle'] as String? ?? '',
      typeLabel: j['typeLabel'] as String? ?? '',
      ok: j['ok'] == true,
      at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      detail: j['detail'] as String?,
    );
  }
}

/// One row from course rollcall history (server).
class CourseRollcallRecord {
  const CourseRollcallRecord({
    required this.courseId,
    required this.courseTitle,
    required this.rollcallId,
    required this.rollcallTime,
    required this.typeLabel,
    required this.signedStatus,
    required this.platformStatus,
    this.detail = '',
  });

  final String courseId;
  final String courseTitle;
  final String rollcallId;
  final DateTime? rollcallTime;
  final String typeLabel;
  final String signedStatus;
  final String platformStatus;
  final String detail;

  bool get isPlaceholder => rollcallId == '-' || signedStatus.contains('无签到');

  String get timeLabel {
    final t = rollcallTime;
    if (t == null) return '-';
    return t.toLocal().toString().substring(0, 19);
  }

  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'courseTitle': courseTitle,
    'rollcallId': rollcallId,
    'rollcallTime': rollcallTime?.toIso8601String(),
    'typeLabel': typeLabel,
    'signedStatus': signedStatus,
    'platformStatus': platformStatus,
    'detail': detail,
  };

  factory CourseRollcallRecord.fromJson(Map<String, dynamic> j) {
    return CourseRollcallRecord(
      courseId: '${j['courseId'] ?? ''}',
      courseTitle: j['courseTitle'] as String? ?? '',
      rollcallId: '${j['rollcallId'] ?? ''}',
      rollcallTime: DateTime.tryParse(j['rollcallTime'] as String? ?? ''),
      typeLabel: j['typeLabel'] as String? ?? '',
      signedStatus: j['signedStatus'] as String? ?? '',
      platformStatus: j['platformStatus'] as String? ?? '',
      detail: j['detail'] as String? ?? '',
    );
  }
}
