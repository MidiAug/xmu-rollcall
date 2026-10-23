import 'package:flutter/foundation.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';

/// Notification delivery policy independent of native window/plugin APIs.
class DesktopNotifications extends ChangeNotifier {
  DesktopNotifications({
    required this.setup,
    required this.isForeground,
    required this.send,
    required this.showInApp,
    this.sendQuiet,
  });

  final Future<void> Function() setup;
  final Future<bool> Function() isForeground;
  final Future<void> Function(String body, bool test) send;
  final bool Function(String body) showInApp;
  final Future<void> Function(String body)? sendQuiet;
  bool ready = false;
  String? error;
  DateTime? lastTestSentAt;
  DateTime? lastTestConfirmedAt;
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
    final body = test ? '收到这条通知后，点击返回应用。' : '发现 $count 条进行中的签到，点击查看。';
    return _deliver(body, test: test);
  }

  void confirmTest() {
    if (lastTestSentAt == null || error != null) return;
    lastTestConfirmedAt = DateTime.now();
    notifyListeners();
  }

  Future<bool> notifyResult(String courseTitle, bool ok) => _deliver(
    '$courseTitle：${ok ? '自动签到成功' : '自动签到未成功，请打开签到页处理'}',
    quiet: true,
  );

  Future<bool> _deliver(
    String body, {
    bool test = false,
    bool quiet = false,
  }) async {
    if (test) {
      // A failed retest must not leave an older confirmation visible.
      lastTestSentAt = null;
      lastTestConfirmedAt = null;
      notifyListeners();
    }
    try {
      // Suppress system alerts only when the application is actually in focus.
      if (!test && await isForeground() && showInApp(body)) return true;
      if (!ready) await initialize();
      if (!ready) return false;
      if (quiet && sendQuiet != null) {
        await sendQuiet!(body);
      } else {
        await send(body, test);
      }
      error = null;
      if (test) {
        lastTestSentAt = DateTime.now();
        lastTestConfirmedAt = null;
      }
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
