import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_page_routes.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/platform/android_monitor_shell.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

const _verifiedKey = 'background_reminder_verified_v1';
const _guidedKey = 'background_reminder_guided_v2';
const _pendingKey = 'background_reminder_pending_v1';

/// Guidance is advisory; the detector has already started.
Future<void> showBackgroundReminderSetup(BuildContext context) async {
  if (!PlatformHooks.isAndroid) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final status = await AndroidMonitorShell.instance
        .readNotificationSettings();
    final blocked = status.discoveryBlocked || status.ongoingAlerts;
    final previous = prefs.getString(_verifiedKey);
    final verified = previous == status.settingsFingerprint;
    final changed = previous != null && !verified;
    if (!blocked &&
        !changed &&
        (verified || prefs.getBool(_guidedKey) == true)) {
      return;
    }
    if (!context.mounted) return;
    await prefs.setBool(_guidedKey, true);
    if (context.mounted) {
      await AppPageRoutes.push(context, const NotificationSettingsPage());
    }
  } catch (_) {
    // A failed settings check must not cancel the running detector.
  }
}

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, this.readStatus});
  final Future<AndroidDiscoveryNotificationStatus> Function()? readStatus;
  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  AndroidDiscoveryNotificationStatus? _status;
  late final AppLifecycleListener _lifecycle;
  Timer? _ticker;
  DateTime? _deadline;
  String? _testFingerprint;
  String? _verifiedFingerprint;
  bool _loading = true;
  bool _readFailed = false;
  bool _busy = false;
  bool _showHelp = false;

  Future<AndroidDiscoveryNotificationStatus> _readStatus() =>
      widget.readStatus?.call() ??
      AndroidMonitorShell.instance.readNotificationSettings();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_refresh()));
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final status = await _readStatus();
      final prefs = await SharedPreferences.getInstance();
      DateTime? pendingDeadline;
      String? pendingFingerprint;
      final raw = prefs.getString(_pendingKey);
      if (raw != null) {
        try {
          final data = jsonDecode(raw) as Map;
          final deadline = DateTime.fromMillisecondsSinceEpoch(
            data['deadlineMs'] as int,
          );
          final now = DateTime.now();
          final fingerprint = data['fingerprint'] as String;
          if (deadline.isAfter(now.subtract(const Duration(minutes: 10))) &&
              deadline.isBefore(now.add(const Duration(minutes: 2))) &&
              fingerprint.isNotEmpty) {
            pendingDeadline = deadline;
            pendingFingerprint = fingerprint;
          }
        } catch (_) {
          // A damaged or expired confirmation should permit a new test.
        }
        if (pendingDeadline == null) await prefs.remove(_pendingKey);
      }
      if (!mounted) return;
      setState(() {
        _status = status;
        _verifiedFingerprint = prefs.getString(_verifiedKey);
        if (!_busy) {
          _deadline = pendingDeadline;
          _testFingerprint = pendingFingerprint;
        }
        _readFailed = false;
        _loading = false;
      });
      _startTicker();
    } catch (_) {
      if (mounted) {
        setState(() {
          _readFailed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _open(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) AppToast.show(context, '请在手机设置中找到「厦大签到」', error: true);
    }
  }

  Future<void> _startTest() async {
    if (_busy || _deadline != null) return;
    final status = _status;
    if (status == null || _readFailed) {
      await _refresh();
      return;
    }
    if (status.enabled == false) {
      await _open(AndroidMonitorShell.instance.openAppNotificationSettings);
      return;
    }
    if (status.discoveryBlocked) {
      await _open(
        AndroidMonitorShell.instance.openDiscoveryNotificationSettings,
      );
      return;
    }
    if (status.ongoingAlerts) {
      await _open(AndroidMonitorShell.instance.openOngoingNotificationSettings);
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = await AndroidMonitorShell.instance.scheduleDiagnostic(
        const Duration(seconds: 30),
      );
      if (!mounted) return;
      if (!ok) {
        AppToast.show(context, '测试未能启动，请检查通知权限', error: true);
        await _refresh();
        return;
      }
      // Starting the first service also creates its quiet notification channel.
      // Capture settings after that creation so a fresh install can retain its confirmation.
      final startedStatus = await _readStatus();
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingKey,
        jsonEncode({
          'deadlineMs': deadline.millisecondsSinceEpoch,
          'fingerprint': startedStatus.settingsFingerprint,
        }),
      );
      if (!mounted) return;
      setState(() {
        _deadline = deadline;
        _status = startedStatus;
        _testFingerprint = startedStatus.settingsFingerprint;
        _showHelp = false;
      });
      _startTicker();
    } catch (_) {
      if (mounted) AppToast.show(context, '暂时无法启动测试，请稍后重试', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmTest(bool received) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _ticker?.cancel();
      final prefs = await SharedPreferences.getInstance();
      if (received && _testFingerprint != null) {
        await prefs.setString(_verifiedKey, _testFingerprint!);
      } else if (!received) {
        await prefs.remove(_verifiedKey);
      }
      await prefs.remove(_pendingKey);
      if (!mounted) return;
      setState(() {
        _verifiedFingerprint = received ? _testFingerprint : null;
        _deadline = null;
        _showHelp = !received;
      });
      await _refresh();
    } catch (_) {
      if (mounted) AppToast.show(context, '未能保存确认，请稍后重试', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startTicker() {
    if (_ticker?.isActive == true ||
        _deadline == null ||
        !DateTime.now().isBefore(_deadline!)) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _deadline == null) {
        timer.cancel();
        return;
      }
      setState(() {});
      if (!DateTime.now().isBefore(_deadline!)) timer.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final status = _status;
    final verified =
        !_readFailed &&
        status != null &&
        !status.discoveryBlocked &&
        !status.ongoingAlerts &&
        _verifiedFingerprint == status.settingsFingerprint;
    final remaining =
        _deadline?.difference(DateTime.now()).inSeconds.clamp(0, 30) ?? 0;
    final waiting = _deadline != null && remaining > 0;
    final xiaomi = '${status?.background['manufacturer'] ?? ''}'
        .toLowerCase()
        .contains('xiaomi');
    String action = '测试锁屏提醒';
    String instruction = '点此后锁屏等待 30 秒，收到预期提醒后返回确认。测试不会请求课程接口，也不会提交签到。';
    if (_loading) {
      action = '正在检查…';
    } else if (_readFailed) {
      action = '重新检查';
      instruction = '暂时无法读取设置，请重试。';
    } else if (status?.enabled == false) {
      action = '允许本应用通知';
      instruction = '打开系统通知设置，允许厦大签到发送通知。';
    } else if (status?.discoveryBlocked == true) {
      action = '开启发现提醒';
      instruction = '在「签到发现」类别中允许通知；声音、震动和横幅按你的习惯选择。';
    } else if (status?.ongoingAlerts == true) {
      action = '让倒计时保持安静';
      instruction = '在「签到检测」类别中关闭声音、震动与悬浮，保留允许通知。';
    } else if (verified) {
      action = '重新测试';
      instruction = '你已确认收到锁屏提醒。更换手机或调整系统设置后，可在这里重新测试。';
    }
    return SubpageScaffold(
      title: '后台提醒',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpace.pageXOf(context),
          AppSpace.md,
          AppSpace.pageXOf(context),
          AppSpace.xl,
        ),
        children: [
          SettingsSection(
            padTop: false,
            header: verified ? '提醒已实测' : '检查 → 测试 → 确认收到',
            children: [
              SettingsRow(
                leading: Icon(
                  verified
                      ? Icons.check_circle_outline
                      : Icons.notifications_active_outlined,
                ),
                title: waiting
                    ? '请锁屏等待  ${remaining}s'
                    : _deadline != null
                    ? '刚才收到提醒了吗？'
                    : action,
                subtitle: waiting
                    ? '测试结束后自动停止临时任务'
                    : _deadline != null
                    ? '确认实际收到预期提醒；声音、震动和横幅由手机设置决定'
                    : instruction,
                trailing: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _loading || _busy || _deadline != null
                    ? null
                    : _startTest,
              ),
              if (_deadline != null && !waiting)
                Padding(
                  padding: AppDensity.rowPadding(context),
                  child: Wrap(
                    spacing: 12,
                    children: [
                      FilledButton(
                        onPressed: () => _confirmTest(true),
                        child: const Text('已收到提醒'),
                      ),
                      TextButton(
                        onPressed: () => _confirmTest(false),
                        child: const Text('没有收到'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_showHelp)
            SettingsSection(
              header: '按表现调整',
              children: [
                SettingsRow(
                  leading: const Icon(Icons.notifications_outlined),
                  title: '通知出现，但没有震动或横幅',
                  subtitle: '检查「签到发现」中的声音、震动和悬浮选项',
                  onTap: () => _open(
                    AndroidMonitorShell
                        .instance
                        .openDiscoveryNotificationSettings,
                  ),
                ),
                SettingsRow(
                  leading: const Icon(Icons.battery_saver_outlined),
                  title: '锁屏没收到，解锁后才收到',
                  subtitle: xiaomi ? '打开省电策略，选择「无限制」' : '在应用信息中允许后台运行，取消省电限制',
                  onTap: () => _open(
                    AndroidMonitorShell.instance.openAppBackgroundSettings,
                  ),
                ),
                Padding(
                  padding: AppDensity.rowPadding(context),
                  child: Text(
                    '调整后再测试一次；两次提醒间隔至少 30 秒，避免系统限制连续震动。静音和勿扰模式也会影响提醒。',
                    style: TextStyle(fontSize: 13, height: 1.5, color: p.muted),
                  ),
                ),
              ],
            ),
          ExpansionTile(
            title: const Text('更多选项与排查'),
            children: [
              SettingsRow(
                title: '发现通知设置',
                subtitle: '声音可按个人习惯选择；锁屏内容也在这里设置',
                onTap: () => _open(
                  AndroidMonitorShell
                      .instance
                      .openDiscoveryNotificationSettings,
                ),
              ),
              SettingsRow(
                title: '后台运行设置',
                subtitle: xiaomi ? '省电策略 → 无限制；仅在锁屏检测延迟时需要' : '仅在锁屏后检测延迟时调整',
                onTap: () => _open(
                  AndroidMonitorShell.instance.openAppBackgroundSettings,
                ),
              ),
              if (status?.background['batteryExempt'] == false)
                SettingsRow(
                  title: '系统电池优化',
                  subtitle: '如果应用省电策略调整后仍有延迟，可允许忽略优化',
                  onTap: () => _open(
                    AndroidMonitorShell
                        .instance
                        .openBatteryOptimizationSettings,
                  ),
                ),
              SettingsRow(
                title: '常驻倒计时设置',
                subtitle: '默认安静，不需要开启声音、震动或悬浮',
                onTap: () => _open(
                  AndroidMonitorShell.instance.openOngoingNotificationSettings,
                ),
              ),
              Padding(
                padding: AppDensity.rowPadding(context),
                child: Text(
                  '需要显示课程内容时，将锁屏规则设为「显示通知及其内容」。'
                  '需要通知时亮屏，可在手机的锁屏或通知光效设置中选择亮屏；这是可选的全局设置。'
                  '\n\n系统检查不能读取所有厂商开关，请以实际测试为准。',
                  style: TextStyle(fontSize: 13, height: 1.5, color: p.muted),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.md),
            child: Text(
              '开始检测 → 发现签到 → 提醒或按规则自动提交。检测倒计时保持安静，自动提交结果更新原提醒。退出账号、手动停止或达到系统后台时限后停止检测。',
              style: TextStyle(fontSize: 12, height: 1.5, color: p.muted),
            ),
          ),
        ],
      ),
    );
  }
}
