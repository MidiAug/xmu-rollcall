import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
import 'package:xmu_rollcall/features/update/github_update_service.dart';
import 'package:xmu_rollcall/platform/app_update_installer.dart';

enum _UpdatePhase { available, downloading, ready, installing, failed }

class AppUpdateSection extends StatefulWidget {
  const AppUpdateSection({
    super.key,
    this.package,
    this.controller,
    this.service,
    this.installer,
    this.target,
  });
  final Future<PackageInfo>? package;
  final AppUpdateController? controller;
  final UpdateService? service;
  final UpdateInstaller? installer;
  final UpdateTarget? target;
  @override
  State<AppUpdateSection> createState() => _AppUpdateSectionState();
}

class _AppUpdateSectionState extends State<AppUpdateSection> {
  late final AppUpdateController _controller =
      widget.controller ??
      AppUpdateController(
        service: widget.service,
        package: widget.package == null ? null : () => widget.package!,
        target: widget.target,
      );
  UpdateService get _service => _controller.service;
  late final UpdateInstaller _installer =
      widget.installer ?? AppUpdateInstaller();
  UpdateTarget? get _target => _controller.target;
  _UpdatePhase _phase = _UpdatePhase.available;
  CancelToken _cancel = CancelToken();
  ReleaseUpdate? _downloadUpdate;
  ReleaseUpdate? get _update => _downloadUpdate ?? _controller.update;
  File? _file;
  bool _confirming = false;
  double? _progress;
  String _message = '';
  bool get _busy =>
      _controller.status == UpdateCheckStatus.checking ||
      {_UpdatePhase.downloading, _UpdatePhase.installing}.contains(_phase);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.check();
    });
  }

  @override
  void dispose() {
    _cancel.cancel();
    _controller.removeListener(_refresh);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _fail(Object error, {bool installing = false}) {
    if (!mounted) return;
    setState(() {
      _phase = installing && _file != null
          ? _UpdatePhase.ready
          : _UpdatePhase.failed;
      _message = error is UpdateException ? error.message : '暂时无法完成更新，请检查网络后重试';
    });
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() {
      _phase = _UpdatePhase.available;
      _message = '';
      _downloadUpdate = null;
      _file = null;
    });
    await _controller.check(force: true);
  }

  Future<void> _download() async {
    final update = _update;
    if (_busy || update == null) return;
    _cancel = CancelToken();
    setState(() {
      _downloadUpdate = update;
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

  Future<void> _showReleaseNotes() async {
    final update = _update;
    if (update == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('更新说明 · v${update.version.name}'),
        content: SingleChildScrollView(child: SelectableText(update.notes)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    final p = AppPalette.of(context);
    final checking = _controller.status == UpdateCheckStatus.checking;
    final status = switch (_phase) {
      _UpdatePhase.downloading => _message,
      _UpdatePhase.ready => _message,
      _UpdatePhase.installing => '正在打开安装器…',
      _UpdatePhase.failed => _message,
      _ =>
        _message.isNotEmpty
            ? _message
            : update != null
            ? '有更新 · v${update.version.name}'
            : switch (_controller.status) {
                UpdateCheckStatus.idle ||
                UpdateCheckStatus.checking => '正在检查新版本',
                UpdateCheckStatus.current => '已是最新版本',
                UpdateCheckStatus.failed => '暂时无法检查',
                UpdateCheckStatus.available => '有更新',
              },
    };
    final (label, icon, callback) = switch (_phase) {
      _UpdatePhase.downloading => (
        '取消下载',
        Icons.close_rounded,
        () => _cancel.cancel(),
      ),
      _UpdatePhase.ready => (
        _target == UpdateTarget.windows ? '退出并安装' : '安装更新',
        _target == UpdateTarget.windows
            ? Icons.install_desktop_rounded
            : Icons.install_mobile_rounded,
        _install,
      ),
      _ =>
        update != null
            ? (
                _phase == _UpdatePhase.failed ? '重新下载' : '下载更新',
                Icons.download_rounded,
                _download,
              )
            : ('检查更新', Icons.refresh_rounded, _check),
    };
    final waiting = checking || _phase == _UpdatePhase.installing;
    Widget row = Semantics(
      liveRegion: true,
      child: SettingsRow(
        leading: _phase == _UpdatePhase.downloading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.system_update_alt_rounded),
        title: '检查更新',
        subtitle: status,
        onTap: update != null ? _showReleaseNotes : (_busy ? null : _check),
        trailing: SizedBox.square(
          dimension: 44,
          child: waiting
              ? Center(
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.muted,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: label,
                  onPressed: callback,
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.standard,
                  ),
                  icon: Icon(icon, size: 20),
                  color: update != null ? p.primary : p.muted,
                ),
        ),
      ),
    );
    if (update != null) {
      row = Tooltip(message: '查看更新说明', child: row);
    } else if (_controller.error != null) {
      row = Tooltip(message: _controller.error!, child: row);
    }
    return SettingsSection(header: '应用更新', padTop: false, children: [row]);
  }
}
