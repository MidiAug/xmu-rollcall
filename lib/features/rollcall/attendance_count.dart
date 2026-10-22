/// Threshold strategy informed by alkali210/XMU-Rollcall-Bot's
/// rollcall_handler.py. Evaluate once per monitor cycle instead of blocking
/// discovery in a five-minute sleep loop. Never infer attendance from timestamps.
class AttendanceCount {
  const AttendanceCount(this.signed, this.total);
  final int signed;
  final int total;

  static AttendanceCount parse(Object? payload, {required int rollcallId}) {
    Object? data = payload;
    if (data is Map && data['student_rollcalls'] == null) data = data['data'];
    if (data is! Map || data['student_rollcalls'] is! List) {
      throw const FormatException('签到人数接口格式不支持');
    }
    final rows = data['student_rollcalls'] as List;
    if (rows.isEmpty ||
        rows.any((r) => r is! Map || r['rollcall_status'] is! String)) {
      throw const FormatException('签到人数暂不可用');
    }
    final total = int.tryParse(
      '${data['total'] ?? data['total_count'] ?? rows.length}',
    );
    if (total == null || total != rows.length) {
      throw const FormatException('签到人数数据不完整');
    }
    for (final row in rows.cast<Map>()) {
      if (row['rollcall_id'] != null &&
          '${row['rollcall_id']}' != '$rollcallId') {
        throw const FormatException('签到人数不属于当前活动');
      }
    }
    return AttendanceCount(
      rows
          .where(
            (r) =>
                r['rollcall_status'].toString().toLowerCase() == 'on_call_fine',
          )
          .length,
      total,
    );
  }
}
