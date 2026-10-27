import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/schedule/academic_calendar.dart';

DateTime semesterDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String semesterLabel(String term) {
  final year = int.tryParse(term.length >= 4 ? term.substring(0, 4) : term);
  if (year == null || term.length != 5) return term;
  final season = {'1': '秋季', '2': '春季', '3': '夏季'}[term[4]] ?? '';
  return '$year—${year + 1}学年 · $season';
}

String currentSemester(DateTime now) {
  final known =
      academicMondays.entries.where((e) => !e.value.isAfter(now)).toList()
        ..sort((a, b) => a.value.compareTo(b.value));
  final expected =
      '${now.month >= 8 ? now.year : now.year - 1}${now.month >= 8 || now.month == 1
          ? 1
          : now.month >= 7
          ? 3
          : 2}';
  if (known.isNotEmpty && academicMondays.containsKey(expected)) {
    return known.last.key;
  }
  return '${now.month >= 8 ? now.year : now.year - 1}${now.month >= 8 || now.month == 1
      ? 1
      : now.month >= 7
      ? 3
      : 2}';
}

/// User-selected first teaching Mondays are independent of remote caches.
abstract final class SemesterPreferences {
  static String key(int uid, String term) => 'term_start_v1_${uid}_$term';
  static Future<DateTime?> read(int uid, String term) async {
    final prefs = await SharedPreferences.getInstance();
    final date = DateTime.tryParse(prefs.getString(key(uid, term)) ?? '');
    return date != null && date.weekday == 1 ? semesterDate(date) : null;
  }

  static Future<void> save(
    int uid,
    String term,
    DateTime? date, {
    void Function()? requireCurrent,
  }) async {
    if (!RegExp(r'^\d{4}[123]$').hasMatch(term) ||
        (date != null && date.weekday != 1)) {
      throw const FormatException('请选择第1周的周一');
    }
    final prefs = await SharedPreferences.getInstance();
    requireCurrent?.call();
    final ok = date == null
        ? await prefs.remove(key(uid, term))
        : await prefs.setString(key(uid, term), TimetableSlot.dateKey(date));
    if (!ok) throw StateError('日期未保存');
  }
}
