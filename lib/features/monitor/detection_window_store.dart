import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'detection_window.dart';

abstract final class DetectionWindowStore {
  static Future<DetectionWindow> read({
    bool reload = false,
    int? uid,
    int? ownerId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    if (ownerId != null &&
        prefs.getInt('schedule_detection_legacy_owner') == null) {
      await prefs.setInt('schedule_detection_legacy_owner', ownerId);
    }
    // Legacy clock-hour restrictions are retired. Existing schedule gating
    // remains enabled by default; the new switch explicitly controls it.
    return DetectionWindow(
      scheduleBased: true,
      enabled:
          (uid == null
              ? null
              : prefs.getBool(
                  '${DetectionWindow.schedulePreferenceKey}_$uid',
                )) ??
          ((uid == null ||
                  prefs.getInt('schedule_detection_legacy_owner') == null ||
                  prefs.getInt('schedule_detection_legacy_owner') == uid)
              ? prefs.getBool(DetectionWindow.schedulePreferenceKey)
              : null) ??
          true,
    );
  }

  static Future<void> save(DetectionWindow window, {int? userId}) async {
    if (window.scheduleBased) {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setBool(
        userId == null
            ? DetectionWindow.schedulePreferenceKey
            : '${DetectionWindow.schedulePreferenceKey}_$userId',
        window.enabled,
      )) {
        throw StateError('无法保存检测范围');
      }
      return;
    }
    if (window.startMinute == window.endMinute ||
        window.startMinute < 0 ||
        window.endMinute < 0 ||
        window.startMinute > 1439 ||
        window.endMinute > 1439) {
      throw ArgumentError('无效检测时段');
    }
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
      DetectionWindow.preferencesKey,
      jsonEncode({
        'enabled': window.enabled,
        'start': window.startMinute,
        'end': window.endMinute,
      }),
    );
    if (!ok) throw StateError('无法保存检测时段');
  }
}
