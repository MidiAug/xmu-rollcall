import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A device-local daily discovery window, shared by owner and assist sessions.
class DetectionWindow {
  const DetectionWindow({
    this.enabled = false,
    this.startMinute = 450,
    this.endMinute = 1320,
  });
  final bool enabled;
  final int startMinute;
  final int endMinute;
  static const preferencesKey = 'rollcall_detection_window';

  static String formatMinute(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
  String get label => '${formatMinute(startMinute)}–${formatMinute(endMinute)}';

  bool allows(DateTime at) {
    if (!enabled) return true;
    final local = at.toLocal();
    final minute = local.hour * 60 + local.minute;
    return startMinute < endMinute
        ? minute >= startMinute && minute < endMinute
        : minute >= startMinute || minute < endMinute;
  }

  DateTime nextStart(DateTime at) {
    final local = at.toLocal();
    final start = DateTime(
      local.year,
      local.month,
      local.day,
      startMinute ~/ 60,
      startMinute % 60,
    );
    return start.isAfter(local)
        ? start
        : DateTime(
            local.year,
            local.month,
            local.day + 1,
            startMinute ~/ 60,
            startMinute % 60,
          );
  }

  static Future<DetectionWindow> read({bool reload = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reload) await prefs.reload();
    try {
      final raw = prefs.getString(preferencesKey);
      if (raw == null) return const DetectionWindow();
      final json = jsonDecode(raw) as Map;
      final start = json['start'] as int;
      final end = json['end'] as int;
      if (start < 0 || start > 1439 || end < 0 || end > 1439 || start == end) {
        return const DetectionWindow();
      }
      return DetectionWindow(
        enabled: json['enabled'] == true,
        startMinute: start,
        endMinute: end,
      );
    } on FormatException {
      return const DetectionWindow();
    } on TypeError {
      return const DetectionWindow();
    }
  }
}

class DetectionWindowClosed implements Exception {
  const DetectionWindowClosed(this.window, this.at);
  final DetectionWindow window;
  final DateTime at;
  @override
  String toString() => '当前不在检测时段（${window.label}），暂不获取签到';
}

final detectionWindowProvider =
    StateNotifierProvider<DetectionWindowController, DetectionWindow?>(
      (ref) => DetectionWindowController(),
    );

class DetectionWindowController extends StateNotifier<DetectionWindow?> {
  DetectionWindowController() : super(null) {
    ready = _load();
  }
  late final Future<void> ready;
  Future<void> _load() async {
    final window = await DetectionWindow.read();
    if (mounted) state = window;
  }

  Future<void> save(DetectionWindow window) async {
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
    if (mounted) state = window;
  }
}
