import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xmu_rollcall/app/app_switch.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/monitor/monitor_controller.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/platform/windows_startup.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

/// App launch preferences live in settings, independently of the sign-in page.
class StartupSettings extends ConsumerStatefulWidget {
  const StartupSettings({super.key, this.showHeader = true});
  final bool showHeader;

  @override
  ConsumerState<StartupSettings> createState() => _StartupSettingsState();
}

class _StartupSettingsState extends ConsumerState<StartupSettings> {
  bool? _startup;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await ref.read(windowsStartupProvider).isEnabled();
      if (mounted) setState(() => _startup = enabled);
    } catch (_) {
      if (mounted) setState(() => _error = '启动设置读取失败，请重新打开此页');
    }
  }

  Future<void> _setStartup(bool value) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(windowsStartupProvider).setEnabled(value);
      if (mounted) setState(() => _startup = value);
    } catch (_) {
      if (mounted) setState(() => _error = '开机启动设置未能保存，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(monitorControllerProvider);
    final config = state.config;
    final signedIn = ref.watch(authControllerProvider).isSignedIn;
    final isOwner = ref.watch(selectedRollcallAccountProvider) == null;
    final startup = ref.watch(windowsStartupProvider);
    return SettingsSection(
      header: widget.showHeader ? '运行与启动' : null,
      hasLeading: !widget.showHeader,
      children: [
        SettingsRow(
          leading: widget.showHeader ? null : const Icon(AppIcons.desktop),
          title: '开机启动',
          subtitle: _error ?? (startup.supported ? null : 'Windows 正式版中可设置'),
          stackSubtitleOnNarrow: true,
          trailing: AppSwitch(
            key: const ValueKey('monitor-startup'),
            value: _startup ?? false,
            onChanged: startup.supported && _startup != null && !_saving
                ? _setStartup
                : null,
          ),
        ),
        SettingsRow(
          leading: widget.showHeader ? null : const Icon(AppIcons.guard),
          title: '启动后继续值守',
          subtitle: !signedIn
              ? '登录主账号后可设置'
              : !isOwner
              ? '切换到主账号后可设置，协助账号需手动开始'
              : !config.courseWatch
              ? '在签到设置中开启课表值守后可设置'
              : '恢复主账号登录后，自动按课表等待',
          stackSubtitleOnNarrow: true,
          trailing: AppSwitch(
            key: const ValueKey('monitor-resume-watch'),
            value: isOwner && config.resumeWatch,
            onChanged:
                signedIn &&
                    isOwner &&
                    !state.loadingSettings &&
                    config.courseWatch
                ? ref.read(monitorControllerProvider.notifier).setResumeWatch
                : null,
          ),
        ),
      ],
    );
  }
}
