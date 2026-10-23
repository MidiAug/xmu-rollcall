import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
import 'package:xmu_rollcall/features/update/app_update_section.dart';
import 'package:xmu_rollcall/features/update/github_update_service.dart';
import 'package:xmu_rollcall/platform/app_update_installer.dart';

/// Real update widgets with simulated transport; reachable only in Debug.
class UpdatePreviewPage extends StatefulWidget {
  const UpdatePreviewPage({super.key}) : assert(kDebugMode);
  @override
  State<UpdatePreviewPage> createState() => _UpdatePreviewPageState();
}

class _UpdatePreviewPageState extends State<UpdatePreviewPage> {
  String _scenario = '有新版';
  UpdateTarget _target = Platform.isAndroid
      ? UpdateTarget.android
      : UpdateTarget.windows;
  int _revision = 0;
  late AppUpdateController _controller = _create();
  AppUpdateController _create() => AppUpdateController(
    target: _target,
    service: _PreviewService(_scenario, _target),
    package: () async => PackageInfo(
      appName: 'preview',
      packageName: 'cn.edu.xmu.rollcall.xmu_rollcall',
      version: '0.1.3',
      buildNumber: '4',
    ),
  );
  void _reset(VoidCallback change) {
    _controller.dispose();
    setState(() {
      change();
      _revision++;
      _controller = _create();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SubpageScaffold(
      title: '更新流程预览',
      body: AppContentColumn(
        maxWidth: 600,
        child: ListView(
          padding: EdgeInsets.all(AppSpace.pageXOf(context)),
          children: [
            Text(
              '模拟检查、下载和安装，可安全查看各个状态。',
              style: TextStyle(fontSize: 13, height: 1.5, color: p.muted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _scenario,
                    decoration: const InputDecoration(labelText: '预览状态'),
                    items: [
                      for (final v in ['有新版', '已是最新', '检查失败', '下载失败'])
                        DropdownMenuItem(value: v, child: Text(v)),
                    ],
                    onChanged: (v) => _reset(() => _scenario = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<UpdateTarget>(
                    initialValue: _target,
                    decoration: const InputDecoration(labelText: '安装平台'),
                    items: [
                      for (final v in UpdateTarget.values)
                        DropdownMenuItem(
                          value: v,
                          child: Text(
                            v == UpdateTarget.windows ? 'Windows' : 'Android',
                          ),
                        ),
                    ],
                    onChanged: (v) => _reset(() => _target = v!),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _reset(() {}),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('重置预览'),
              ),
            ),
            const SizedBox(height: 12),
            AppUpdateSection(
              key: ValueKey(_revision),
              controller: _controller,
              installer: _PreviewInstaller(),
            ),
            const SizedBox(height: 16),
            Text(
              '点击更新行查看说明；下载时可取消或从说明中更换线路。此页展示的 v0.1.4 为测试数据。',
              style: TextStyle(fontSize: 12, height: 1.6, color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewInstaller implements UpdateInstaller {
  @override
  Future<InstallLaunch> install(File file, UpdateTarget target) async =>
      InstallLaunch.launched;
}

class _PreviewService implements UpdateService {
  _PreviewService(this.scenario, this.target);
  final String scenario;
  final UpdateTarget target;
  @override
  Future<ReleaseUpdate?> check(
    AppVersion current,
    UpdateTarget target,
    CancelToken cancel,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (cancel.isCancelled) throw cancel.cancelError!;
    if (scenario == '检查失败') {
      throw const UpdateException('模拟连接超时：可点击此行查看失败详情，或使用右侧按钮重试。');
    }
    if (scenario == '已是最新') return null;
    return ReleaseUpdate(
      version: const AppVersion(0, 1, 4, 5),
      target: target,
      size: 11 * 1024 * 1024,
      sha256: '0' * 64,
      notes: '''### 改进

- 数字签到码持久保存，重启后恢复。
- 检查超时尝试官方备用清单。
- 下载时显示进度、大小和速度。

### 修复

修复同一课堂多次签到时，历史记录刷新不及时的问题。

[查看项目](https://github.com/MidiAug/xmu-rollcall)
''',
    );
  }

  @override
  Future<File> download(
    ReleaseUpdate update,
    CancelToken cancel,
    void Function(int, int) progress,
  ) async {
    for (var received = 0; received < update.size;) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (cancel.isCancelled) throw cancel.cancelError!;
      received = (received + 128 * 1024).clamp(0, update.size);
      progress(received, update.size);
      if (scenario == '下载失败' && received >= update.size * .35) {
        throw const UpdateException('模拟下载中断：可切换线路后重试。');
      }
    }
    return File('preview-only-not-an-installer');
  }

  @override
  Future<void> verify(File file, ReleaseUpdate update) async {}
  @override
  void close() {}
}
