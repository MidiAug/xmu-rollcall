import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/github_update_service.dart';
import 'package:xmu_rollcall/platform/app_update_installer.dart';

enum _UpdatePhase {
  checking,
  current,
  available,
  downloading,
  ready,
  installing,
  failed,
}

class AppUpdateSection extends StatefulWidget {
  const AppUpdateSection({
    super.key,
    required this.package,
    this.service,
    this.installer,
    this.target,
  });
  final Future<PackageInfo> package;
  final UpdateService? service;
  final UpdateInstaller? installer;
  final UpdateTarget? target;
  @override
  State<AppUpdateSection> createState() => _AppUpdateSectionState();
}

class _AppUpdateSectionState extends State<AppUpdateSection> {
  late final UpdateService _service = widget.service ?? GithubUpdateService();
  late final UpdateInstaller _installer =
      widget.installer ?? AppUpdateInstaller();
  late final UpdateTarget? _target =
      widget.target ??
      (Platform.isAndroid
          ? UpdateTarget.android
          : Platform.isWindows
          ? UpdateTarget.windows
          : null);
  _UpdatePhase _phase = _UpdatePhase.checking;
  CancelToken _cancel = CancelToken();
  ReleaseUpdate? _update;
  File? _file;
  bool _confirming = false;
  double? _progress;
  String _message = '正在检查 GitHub 正式版本…';
  bool get _busy => {
    _UpdatePhase.checking,
    _UpdatePhase.downloading,
    _UpdatePhase.installing,
  }.contains(_phase);

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _cancel.cancel();
    _service.close();
    super.dispose();
  }

  void _fail(Object error, {bool installing = false}) {
    if (!mounted) return;
    setState(() {
      _phase = installing && _file != null
          ? _UpdatePhase.ready
          : _UpdatePhase.failed;
      _message = error is UpdateException
          ? error.message
          : '暂时无法完成更新，请检查网络后重试，或打开发布页';
    });
  }

  Future<void> _check() async {
    _cancel = CancelToken();
    setState(() {
      _phase = _UpdatePhase.checking;
      _message = '正在检查 GitHub 正式版本…';
      _update = null;
      _file = null;
    });
    try {
      final package = await widget.package;
      if (!mounted) return;
      if (_target == null) throw const UpdateException('当前平台请从 GitHub 发布页手动更新');
      if (_target == UpdateTarget.android &&
          package.packageName != 'cn.edu.xmu.rollcall.xmu_rollcall') {
        throw const UpdateException('测试版与正式版独立安装，请从发布页获取正式版');
      }
      final version = AppVersion.parse(
        '${package.version}+${package.buildNumber}',
      );
      final update = await _service.check(version, _target, _cancel);
      if (!mounted) return;
      setState(() {
        _update = update;
        _phase = update == null ? _UpdatePhase.current : _UpdatePhase.available;
        _message = update == null
            ? '当前已是最新正式版本'
            : '发现新版本 ${update.version.name}';
      });
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _download() async {
    final update = _update;
    if (_busy || update == null) return;
    _cancel = CancelToken();
    setState(() {
      _phase = _UpdatePhase.downloading;
      _progress = 0;
      _message = '正在下载安装包…';
    });
    try {
      final file = await _service.download(update, _cancel, (received, total) {
        if (!mounted) return;
        setState(() {
          _progress = received / total;
          _message = received == total
              ? '正在校验安装包…'
              : '正在下载 ${(received / total * 100).floor()}%';
        });
      });
      if (!mounted) return;
      setState(() {
        _file = file;
        _phase = _UpdatePhase.ready;
        _message = '下载完成，安装包校验通过';
      });
    } catch (error) {
      if (!mounted) return;
      if (_cancel.isCancelled) {
        setState(() {
          _phase = _UpdatePhase.available;
          _message = '下载已取消，可重新下载';
        });
      } else {
        _fail(error);
      }
    }
  }

  Future<void> _install() async {
    if (_busy || _confirming || _file == null || _update == null) return;
    _confirming = true;
    final windows = _target == UpdateTarget.windows;
    final confirm = await showAppConfirmDialog(
      context,
      title: windows ? '退出并安装更新？' : '安装更新？',
      message: windows
          ? '将停止检测并退出应用，再打开安装向导。安装版沿用已有安装目录；便携版会转为安装版。'
          : '将打开系统安装器。若需允许此来源安装，请授权后返回这里，再点“安装更新”。兼容签名的更新保留原有数据。',
      confirmLabel: windows ? '退出并安装' : '打开安装器',
    );
    _confirming = false;
    if (!confirm || !mounted || _busy) return;
    setState(() {
      _phase = _UpdatePhase.installing;
      _message = '正在打开安装器…';
    });
    var verified = false;
    try {
      await _service.verify(_file!, _update!);
      verified = true;
      if (!mounted) return;
      final result = await _installer.install(_file!, _target!);
      if (!mounted) return;
      setState(() {
        _phase = _UpdatePhase.ready;
        _message = result == InstallLaunch.permissionRequired
            ? '允许此来源安装后，返回这里再次点击“安装更新”'
            : '已打开系统安装器，请按系统提示完成安装';
      });
    } catch (error) {
      if (!verified) _file = null;
      _fail(error, installing: verified);
    }
  }

  Future<void> _openRelease() async {
    try {
      if (!await launchUrl(
        _update?.page ?? ReleaseUpdate.releasesPage,
        mode: LaunchMode.externalApplication,
      )) {
        throw const UpdateException(
          '无法打开浏览器，请到 GitHub 的 MidiAug/xmu-rollcall 发布页下载',
        );
      }
    } catch (error) {
      _fail(error, installing: _file != null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    final p = AppPalette.of(context);
    return SettingsSection(
      header: '应用更新',
      children: [
        SettingsRow(
          leading: Icon(
            _phase == _UpdatePhase.current
                ? Icons.check_circle_outline
                : Icons.system_update_alt,
          ),
          title: _message,
          subtitle: '仅检查 GitHub 公开正式版本，不上传账号信息。',
        ),
        Padding(
          padding: AppDensity.rowPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_phase == _UpdatePhase.downloading) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 12),
              ],
              if (update != null) ...[
                Text(
                  '${update.target == UpdateTarget.android ? 'Android APK' : 'Windows x64 安装器'} · ${(update.size / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: TextStyle(color: p.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('查看更新说明'),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        update.notes,
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ],
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (_phase == _UpdatePhase.downloading)
                    TextButton(
                      onPressed: () => _cancel.cancel(),
                      child: const Text('取消下载'),
                    )
                  else if (_phase == _UpdatePhase.ready)
                    FilledButton(
                      onPressed: _install,
                      child: Text(
                        _target == UpdateTarget.windows ? '退出并安装' : '安装更新',
                      ),
                    )
                  else if (update != null && !_busy)
                    FilledButton(
                      onPressed: _download,
                      child: Text(
                        _phase == _UpdatePhase.failed ? '重新下载' : '下载更新',
                      ),
                    ),
                  TextButton(
                    onPressed: _busy ? null : _check,
                    child: Text(
                      _phase == _UpdatePhase.checking ? '正在检查…' : '检查更新',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _openRelease,
                    child: const Text('GitHub 发布页'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
