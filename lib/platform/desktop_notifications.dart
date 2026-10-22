import 'package:flutter/foundation.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';

/// Notification delivery policy independent of native window/plugin APIs.
class DesktopNotifications extends ChangeNotifier {
  DesktopNotifications({
    required this.setup,
    required this.isForeground,
    required this.send,
    required this.showInApp,
  });

  final Future<void> Function() setup;
  final Future<bool> Function() isForeground;
  final Future<void> Function(String body, bool test) send;
  final bool Function(String body) showInApp;
  bool ready = false;
  String? error;
  DateTime? lastTestSentAt;
  Future<void>? _initializing;

  Future<void> initialize() =>
      _initializing ??= _initialize().whenComplete(() => _initializing = null);

  Future<void> _initialize() async {
    try {
      await setup();
      ready = true;
      error = null;
    } catch (failure, stack) {
      ready = false;
      error = '系统通知初始化失败，请重试';
      AppLog.logAppError(
        error: failure,
        stackTrace: stack,
        source: 'desktop_notify_setup',
      );
    }
    notifyListeners();
  }

  Future<bool> notify(int count, {bool test = false}) async {
    if (count <= 0 && !test) return true;
    final body = test ? '桌面通知测试：点击此通知返回应用' : '发现进行中签到 $count 条，点击查看';
    try {
      // Suppress system alerts only when the application is actually in focus.
      if (!test && await isForeground() && showInApp(body)) return true;
      if (!ready) await initialize();
      if (!ready) return false;
      await send(body, test);
      error = null;
      if (test) lastTestSentAt = DateTime.now();
      notifyListeners();
      return true;
    } catch (failure, stack) {
      error = '通知发送失败，请检查系统通知设置后重试';
      AppLog.logAppError(
        error: failure,
        stackTrace: stack,
        source: 'desktop_notify',
      );
      notifyListeners();
      return false;
    }
  }
}
