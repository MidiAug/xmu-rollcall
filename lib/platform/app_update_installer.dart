import 'dart:io';
import 'package:flutter/services.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/platform/desktop_shell.dart';

enum InstallLaunch { launched, permissionRequired }

abstract interface class UpdateInstaller {
  Future<InstallLaunch> install(File file, UpdateTarget target);
}

class AppUpdateInstaller implements UpdateInstaller {
  static const channel = MethodChannel('xmu_rollcall/update');
  @override
  Future<InstallLaunch> install(File file, UpdateTarget target) async {
    if (target == UpdateTarget.android && Platform.isAndroid) {
      try {
        final result = await channel.invokeMethod<String>('installApk', {
          'path': file.path,
        });
        if (result == 'permission_required') {
          return InstallLaunch.permissionRequired;
        }
        if (result != 'launched') throw const UpdateException('未能打开系统安装器');
      } on PlatformException catch (error) {
        throw UpdateException(error.message ?? '未能打开系统安装器，请查看发布页');
      }
    } else if (target == UpdateTarget.windows && Platform.isWindows) {
      // The installer waits for this PID before checking for a running window.
      // No shell interpolation, silent mode, or forced process termination.
      await Process.start(file.path, [
        '/UPDATEPID=$pid',
      ], mode: ProcessStartMode.detached);
      await DesktopShell.instance.quitApp(stopPolling: true);
    } else {
      throw const UpdateException('当前平台请从发布页手动更新');
    }
    return InstallLaunch.launched;
  }
}
