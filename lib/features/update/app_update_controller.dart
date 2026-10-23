import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/github_update_service.dart';

enum UpdateCheckStatus { idle, checking, current, available, failed }

final appUpdateControllerProvider = ChangeNotifierProvider<AppUpdateController>(
  (ref) => AppUpdateController(),
);

/// One app-scoped check supplies both the About page and its menu badge.
class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    UpdateService? service,
    Future<PackageInfo> Function()? package,
    UpdateTarget? target,
    DateTime Function()? now,
  }) : service = service ?? GithubUpdateService(),
       _package = package ?? PackageInfo.fromPlatform,
       target =
           target ??
           (Platform.isAndroid
               ? UpdateTarget.android
               : Platform.isWindows
               ? UpdateTarget.windows
               : null),
       _now = now ?? DateTime.now;
  final UpdateService service;
  final Future<PackageInfo> Function() _package;
  final UpdateTarget? target;
  final DateTime Function() _now;
  final CancelToken _cancel = CancelToken();
  UpdateCheckStatus status = UpdateCheckStatus.idle;
  ReleaseUpdate? update;
  DateTime? lastCheckedAt;
  DateTime? _lastAttemptAt;
  String? error;
  Future<void>? _pending;
  bool _disposed = false;

  Future<void> check({bool force = false}) {
    if (_disposed) return Future.value();
    if (_pending != null) return _pending!;
    final attempted = _lastAttemptAt;
    final interval = error == null
        ? const Duration(hours: 6)
        : const Duration(minutes: 30);
    if (!force &&
        attempted != null &&
        _now().difference(attempted) < interval) {
      return Future.value();
    }
    return _pending = Future<void>.microtask(
      _performCheck,
    ).whenComplete(() => _pending = null);
  }

  Future<void> _performCheck() async {
    _lastAttemptAt = _now();
    status = UpdateCheckStatus.checking;
    notifyListeners();
    try {
      final package = await _package();
      if (_disposed) return;
      if (target == null) throw const UpdateException('当前平台请从发布页手动更新');
      if (target == UpdateTarget.android &&
          package.packageName != 'cn.edu.xmu.rollcall.xmu_rollcall') {
        throw const UpdateException('测试版与正式版独立安装，请从发布页获取正式版');
      }
      final version = AppVersion.parse(
        '${package.version}+${package.buildNumber}',
      );
      final result = await service.check(version, target!, _cancel);
      if (_disposed) return;
      update = result;
      lastCheckedAt = _now();
      error = null;
      status = result == null
          ? UpdateCheckStatus.current
          : UpdateCheckStatus.available;
    } catch (failure) {
      if (_disposed) return;
      error = failure is UpdateException
          ? failure.message
          : '暂时无法连接更新服务，请稍后重试或打开发布页。';
      status = UpdateCheckStatus.failed;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel.cancel();
    service.close();
    super.dispose();
  }
}
