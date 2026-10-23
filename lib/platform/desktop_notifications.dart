import 'package:flutter/foundation.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';
import 'package:xmu_rollcall/platform/desktop_notification_content.dart';

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
  final Future<void> Function(DesktopNotificationContent content, bool test)
  send;
  final bool Function(String body) showInApp;
  final Future<void> Function(DesktopNotificationContent content)? sendQuiet;
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

  Future<bool> notify(List<RollcallItem> items) async {
    if (items.isEmpty) return true;
    return _deliver(DesktopNotificationContent.discovery(items));
  }

  Future<bool> test() => _deliver(DesktopNotificationContent.test, test: true);

  void confirmTest() {
    if (lastTestSentAt == null || error != null) return;
    lastTestConfirmedAt = DateTime.now();
    notifyListeners();
  }

  Future<bool> notifyResult(RollcallItem item, bool ok) =>
      _deliver(DesktopNotificationContent.result(item, ok), quiet: true);

  Future<bool> _deliver(
    DesktopNotificationContent content, {
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
      if (!test && await isForeground() && showInApp(content.inAppText)) {
        return true;
      }
      if (!ready) await initialize();
      if (!ready) return false;
      if (quiet && sendQuiet != null) {
        await sendQuiet!(content);
      } else {
        await send(content, test);
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
