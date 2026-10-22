import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';

/// Only a previously observed event inside that exact class window can restore.
List<Map<String, dynamic>> cacheActiveRollcalls(
  List<RollcallItem> items,
  CourseCatalogSnapshot? catalog,
  DateTime observedAt,
) {
  final day = observedAt.toLocal();
  final courses = {
    for (final c in catalog?.courses ?? <CatalogCourse>[]) c.id: c,
  };
  final rows = <Map<String, dynamic>>[];
  for (final item in items) {
    if (item.isExpired) continue;
    final slots = courses[item.courseId]?.timetables[day.weekday];
    if (slots == null) continue;
    for (final block in splitContiguousBlocks(slots)) {
      final start = DateTime(
        day.year,
        day.month,
        day.day,
        block.coreStart.hour,
        block.coreStart.minute,
      ).subtract(SessionBlock.preBuffer);
      final end = DateTime(
        day.year,
        day.month,
        day.day,
        block.coreEnd.hour,
        block.coreEnd.minute,
      ).add(SessionBlock.postBuffer);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      rows.add({
        'windowStart': start.toUtc().toIso8601String(),
        'windowEnd': end.toUtc().toIso8601String(),
        'rollcall_id': item.rollcallId,
        'course_id': item.courseId,
        'course_title': item.courseTitle,
        'created_by_name': item.createdByName,
        'department_name': item.departmentName,
        'is_number': item.isNumber,
        'is_radar': item.isRadar,
        'is_qrcode': item.isQrcode,
        'status': item.status,
        'rollcall_status': item.rollcallStatus,
        'is_expired': item.isExpired,
        'scored': item.scored,
        if (item.numberCode != null) 'cachedNumberCode': item.numberCode,
      });
      break;
    }
  }
  return rows;
}

List<RollcallItem> restoreActiveRollcalls(
  DiskCacheSnapshot? disk,
  DateTime now,
) {
  if (disk == null || now.isBefore(disk.fetchedAt)) return const [];
  final items = <RollcallItem>[];
  for (final row in disk.items) {
    final start = DateTime.tryParse('${row['windowStart']}');
    final end = DateTime.tryParse('${row['windowEnd']}');
    if (start == null ||
        end == null ||
        disk.fetchedAt.isBefore(start) ||
        disk.fetchedAt.isAfter(end) ||
        now.isBefore(start) ||
        now.isAfter(end)) {
      continue;
    }
    try {
      final item = RollcallItem.fromJson(row);
      if (item.rollcallId <= 0 || item.isExpired) continue;
      final code = row['cachedNumberCode'];
      items.add(item.copyWith(numberCode: code is String ? code : null));
    } catch (_) {
      // One damaged row cannot prevent restoring the other current classes.
    }
  }
  return items;
}
