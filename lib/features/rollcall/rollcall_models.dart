enum RollcallType { number, radar, qrcode, unknown }

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

  /// Populated for [RollcallType.number] after `student_rollcalls` fetch.
  final String? numberCode;

  /// Set when number fetch failed or field missing.
  final String? numberCodeError;

  bool get isAnswered => status == 'on_call_fine';

  bool get isNumber => type == RollcallType.number;
  bool get isRadar => type == RollcallType.radar;
  bool get isQrcode => type == RollcallType.qrcode;

  /// Best-effort course id from list payload (for assist same-course filter).
  String? get courseId {
    for (final k in const ['course_id', 'courseId', 'cid', 'teaching_unit_id']) {
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
      status: status,
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
    final isNumber = d['is_number'] == true;
    final isRadar = d['is_radar'] == true;
    final type = isRadar
        ? RollcallType.radar
        : isNumber
            ? RollcallType.number
            : (d['is_qrcode'] == true
                ? RollcallType.qrcode
                : RollcallType.unknown);

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
    );
  }
}

class AnswerResult {
  const AnswerResult({
    required this.ok,
    this.message,
    this.raw = const {},
  });

  final bool ok;
  final String? message;
  final Map<String, dynamic> raw;
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

  bool get isPlaceholder =>
      rollcallId == '-' || signedStatus.contains('无签到');

  String get timeLabel {
    final t = rollcallTime;
    if (t == null) return '-';
    return t.toLocal().toString().substring(0, 19);
  }
}
