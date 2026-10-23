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
    setState(() => _busy = true);
    final sent = await _notifications.notify(1, test: true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _showHelp = !sent;
    });
    AppToast.show(
      context,
      sent ? '测试通知已发出，请确认系统实际提醒' : '通知发送失败，请按下方指引检查',
      error: !sent,
    );
  }

  Future<void> _openSettings() async {
    try {
      if (await launchUrl(Uri.parse('ms-settings:notifications'))) return;
    } catch (_) {
      // Offer the same manual route when Windows rejects the settings URI.
    }
    if (mounted) {
      AppToast.show(context, '请打开 Windows 设置 → 系统 → 通知', error: true);
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
                  header: confirmed ? '本次提醒已确认' : '先测试，再确认收到',
                  children: [
                    SettingsRow(
                      leading: Icon(
                        confirmed
                            ? Icons.check_circle_outline
                            : Icons.notifications_active_outlined,
                      ),
                      title: confirmed
                          ? '已确认收到桌面提醒'
                          : sent
                          ? '刚才收到测试通知了吗？'
                          : '测试桌面提醒',
                      subtitle: notifications.error ?? '测试始终发送系统通知；点击通知可返回应用。',
                      trailing: FilledButton(
                        onPressed: _busy ? null : _test,
                        child: Text(
                          _busy
                              ? '请稍候…'
                              : sent
                              ? '重新测试'
                              : '测试',
                        ),
                      ),
                    ),
                    if (sent && !confirmed)
                      Padding(
                        padding: AppDensity.rowPadding(context),
                        child: Wrap(
                          spacing: 12,
                          children: [
                            FilledButton(
                              onPressed: _busy
                                  ? null
                                  : notifications.confirmTest,
                              child: const Text('已收到提醒'),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _showHelp = true),
                              child: const Text('没有收到'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (_showHelp)
                  SettingsSection(
                    header: '按表现检查',
                    children: [
                      SettingsRow(
                        leading: const Icon(Icons.settings_outlined),
                        title: '检查系统通知和勿扰模式',
                        subtitle: '允许厦大签到通知，并按需开启横幅与声音，再重新测试。',
                        onTap: PlatformHooks.isWindows ? _openSettings : null,
                      ),
                    ],
                  ),
                SettingsSection(
                  header: '检测时会怎样提醒',
                  children: [
                    const SettingsRow(
                      leading: Icon(Icons.fact_check_outlined),
                      title: '发现与自动签到',
                      subtitle:
                          '前台显示应用内提醒，后台发送系统通知。自动签到需主动开启；提交结果会更新提醒，避免重复响铃。',
                    ),
                    SettingsRow(
                      leading: const Icon(Icons.desktop_windows_outlined),
                      title: '关闭到托盘后继续检测',
                      subtitle: shell.trayAvailable.value
                          ? '可从托盘打开签到或停止检测；退出应用与电脑睡眠后不会继续检测。'
                          : '托盘暂不可用时改为最小化到任务栏；退出应用与电脑睡眠后不会继续检测。',
                    ),
                  ],
                ),
                ExpansionTile(
                  title: const Text('更多设置与排查'),
                  children: [
                    if (PlatformHooks.isWindows)
                      SettingsRow(
                        title: '打开 Windows 通知设置',
                        onTap: _openSettings,
                      ),
                    SettingsRow(
                      title: '通知连接',
                      subtitle:
                          notifications.error ??
                          (notifications.ready
                              ? '已连接；是否实际收到仍需测试确认'
                              : '发送测试时自动连接'),
                      trailing: TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                await notifications.initialize();
                                if (mounted) setState(() => _busy = false);
                              },
                        child: const Text('重试'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  '检测负责发现签到；提交按当前账号的自动签到规则执行。系统设置和通知发送成功，都不能代替一次实际收到提醒的确认。',
                  style: TextStyle(color: p.muted, fontSize: 12, height: 1.5),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
