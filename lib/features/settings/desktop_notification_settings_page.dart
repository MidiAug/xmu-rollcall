import 'package:flutter/material.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/platform/desktop_shell.dart';

class DesktopNotificationSettingsPage extends StatefulWidget {
  const DesktopNotificationSettingsPage({super.key});
  @override
  State<DesktopNotificationSettingsPage> createState() =>
      _DesktopNotificationSettingsPageState();
}

class _DesktopNotificationSettingsPageState
    extends State<DesktopNotificationSettingsPage> {
  bool _busy = false;

  Future<void> _test() async {
    if (_busy) return;
    setState(() => _busy = true);
    final sent = await DesktopShell.instance.notifications.notify(
      1,
      test: true,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    AppToast.show(
      context,
      sent ? '已发送测试通知，请确认系统提醒并点击返回应用' : '通知发送失败，请检查系统通知设置',
      error: !sent,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = DesktopShell.instance;
    final p = AppPalette.of(context);
    return SubpageScaffold(
      title: '桌面提醒',
      body: ListenableBuilder(
        listenable: Listenable.merge([
          shell.notifications,
          shell.trayAvailable,
        ]),
        builder: (context, _) => ListView(
          padding: EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            SettingsSection(
              padTop: false,
              header: '通知',
              children: [
                SettingsRow(
                  leading: const Icon(Icons.notifications_outlined),
                  title: '系统通知服务',
                  subtitle:
                      shell.notifications.error ??
                      (shell.notifications.ready ? '已初始化，可发送测试通知确认' : '尚未初始化'),
                  trailing: TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await shell.notifications.initialize();
                            if (mounted) setState(() => _busy = false);
                          },
                    child: const Text('重试连接'),
                  ),
                ),
                SettingsRow(
                  leading: const Icon(Icons.notification_add_outlined),
                  title: '发送测试通知',
                  subtitle: '即使窗口在前台也会发送；点击系统通知可返回应用',
                  trailing: FilledButton(
                    onPressed: _busy ? null : _test,
                    child: Text(_busy ? '请稍候…' : '测试'),
                  ),
                ),
              ],
            ),
            SettingsSection(
              header: '后台运行',
              children: [
                SettingsRow(
                  leading: const Icon(Icons.desktop_windows_outlined),
                  title: '托盘',
                  subtitle: shell.trayAvailable.value
                      ? '关闭到托盘后继续检测，可右键查看签到或停止检测'
                      : '托盘暂不可用，关闭到托盘会改为最小化到任务栏',
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              '窗口最小化、隐藏或失去焦点时，发现新签到会发送系统通知；前台使用时显示应用内提醒。\n\n若测试通知没有出现，请检查系统通知开关和勿扰模式。电脑睡眠或退出应用后，检测不会继续。',
              style: TextStyle(color: p.muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
