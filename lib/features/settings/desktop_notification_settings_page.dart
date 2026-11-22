import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmu_rollcall/app/app_settings_glyph.dart';
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
      body: AppPageViewport(
        builder: (context, contentInsets) => ListenableBuilder(
          listenable: Listenable.merge([notifications, shell.trayAvailable]),
          builder: (context, _) {
            final sent = notifications.lastTestSentAt != null;
            final confirmed =
                notifications.lastTestConfirmedAt != null &&
                notifications.error == null;
            return ListView(
              padding:
                  contentInsets + EdgeInsets.all(AppSpace.pageXOf(context)),
              children: [
                SettingsSection(
                  padTop: false,
                  children: [
                    SettingsRow(
                      leading: const AppSettingsGlyph(AppSettingsGlyphKind.bell),
                      title: '系统通知',
                      subtitle: '仅发送示例提醒，不会提交签到',
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
                        leading: Icon(AppIcons.error, color: p.danger),
                        title: '未能发送通知',
                        subtitle: '请检查系统设置后重新发送。',
                      )
                    else if (sent)
                      SettingsRow(
                        // Keep the shared text column while response actions
                        // wrap below it; only completion needs a status mark.
                        leading: confirmed
                            ? Icon(AppIcons.checkCircle, color: p.muted)
                            : const SizedBox.shrink(),
                        title: confirmed ? '已确认收到测试通知' : '收到刚才的通知了吗？',
                        subtitleWidget: confirmed
                            ? null
                            : Wrap(
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
                      ),
                    if (_showHelp)
                      SettingsRow(
                        leading: const Icon(AppIcons.settings),
                        title: PlatformHooks.isWindows
                            ? '检查 Windows 通知设置'
                            : '检查系统通知设置',
                        subtitle: '允许厦大签到发送通知，并检查勿扰模式；修改后重新发送测试。',
                        onTap: PlatformHooks.isWindows ? _openSettings : null,
                      ),
                  ],
                ),
                SettingsSection(
                  hasLeading: false,
                  children: [
                    Padding(
                      padding: AppDensity.rowPadding(context),
                      child: Text(
                        shell.trayAvailable.value
                            ? '前台显示应用内提醒，后台或托盘时发送系统通知；退出或睡眠时不检测。'
                            : '前台显示应用内提醒，后台时发送系统通知；退出或睡眠时不检测。',
                        style: AppTypography.body.copyWith(color: p.muted),
                      ),
                    ),
                    if (PlatformHooks.isWindows)
                      SettingsRow(
                        title: 'Windows 通知设置',
                        trailing: Icon(
                          AppIcons.right,
                          size: 18,
                          color: p.muted,
                        ),
                        onTap: _openSettings,
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
