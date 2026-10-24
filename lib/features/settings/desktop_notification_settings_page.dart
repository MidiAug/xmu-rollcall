import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/platform/desktop_shell.dart';
import 'package:xmu_rollcall/platform/desktop_notifications.dart';
import 'package:xmu_rollcall/platform/platform_hooks.dart';

class DesktopNotificationSettingsPage extends StatefulWidget {
  const DesktopNotificationSettingsPage({super.key, this.notifications});
  final DesktopNotifications? notifications;
  @override
  State<DesktopNotificationSettingsPage> createState() =>
      _DesktopNotificationSettingsPageState();
}

class _DesktopNotificationSettingsPageState
    extends State<DesktopNotificationSettingsPage> {
  bool _busy = false;
  bool _showHelp = false;
  DesktopNotifications get _notifications =>
      widget.notifications ?? DesktopShell.instance.notifications;

  Future<void> _test() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _showHelp = false;
    });
    final sent = await _notifications.test();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _showHelp = !sent;
    });
  }

  Future<void> _openSettings() async {
    try {
      if (await launchUrl(Uri.parse('ms-settings:notifications'))) return;
    } catch (_) {
      // Offer the manual route when Windows rejects the settings URI.
    }
    if (mounted) {
      AppToast.show(context, '打开 Windows 设置 → 系统 → 通知', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = DesktopShell.instance;
    final p = AppPalette.of(context);
    final notifications = _notifications;
    return SubpageScaffold(
      title: '桌面提醒',
      body: AppContentColumn(
        child: ListenableBuilder(
          listenable: Listenable.merge([notifications, shell.trayAvailable]),
          builder: (context, _) {
            final sent = notifications.lastTestSentAt != null;
            final confirmed =
                notifications.lastTestConfirmedAt != null &&
                notifications.error == null;
            return ListView(
              padding: EdgeInsets.all(AppSpace.pageXOf(context)),
              children: [
                SettingsSection(
                  padTop: false,
                  header: '通知测试',
                  children: [
                    SettingsRow(
                      leading: const Icon(Icons.notifications_outlined),
                      title: '测试系统通知',
                      subtitle: '使用示例课程测试通知，不会提交签到。',
                      trailing: FilledButton(
                        onPressed: _busy ? null : _test,
                        child: Text(
                          _busy
                              ? '发送中…'
                              : sent
                              ? '重新发送'
                              : '发送测试',
                        ),
                      ),
                    ),
                    if (notifications.error != null)
                      SettingsRow(
                        leading: Icon(Icons.error_outline, color: p.danger),
                        title: '未能发送通知',
                        subtitle: '请检查系统设置后重新发送。',
                      )
                    else if (sent)
                      Padding(
                        padding: AppDensity.rowPadding(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (confirmed) ...[
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                    color: p.muted,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    confirmed ? '已确认收到测试通知' : '收到刚才的通知了吗？',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            if (!confirmed) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: _busy
                                        ? null
                                        : () {
                                            notifications.confirmTest();
                                            setState(() => _showHelp = false);
                                          },
                                    child: const Text('已收到'),
                                  ),
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                              setState(() => _showHelp = true),
                                    child: const Text('没有收到'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (_showHelp)
                      SettingsRow(
                        leading: const Icon(Icons.settings_outlined),
                        title: PlatformHooks.isWindows
                            ? '检查 Windows 通知设置'
                            : '检查系统通知设置',
                        subtitle: '允许厦大签到发送通知，并检查勿扰模式；修改后重新发送测试。',
                        onTap: PlatformHooks.isWindows ? _openSettings : null,
                      ),
                  ],
                ),
                SettingsSection(
                  header: '提醒方式',
                  footer: PlatformHooks.isWindows
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _openSettings,
                            child: const Text('Windows 通知设置'),
                          ),
                        )
                      : null,
                  children: [
                    const SettingsRow(
                      leading: Icon(Icons.fact_check_outlined),
                      title: '发现签到时',
                      subtitle: '在前台时显示应用内提醒，切到后台后发送系统通知。',
                    ),
                    SettingsRow(
                      leading: const Icon(Icons.desktop_windows_outlined),
                      title: '托盘运行',
                      subtitle: shell.trayAvailable.value
                          ? '关闭到托盘后继续检测。退出应用或电脑睡眠时不会检测。'
                          : '托盘暂不可用，请保留应用运行。退出应用或电脑睡眠时不会检测。',
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
