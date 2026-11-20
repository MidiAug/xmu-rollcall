import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xmu_rollcall/platform/app_update_installer.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/github_update_service.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';

enum UpdateDownloadStatus { idle, downloading, ready, failed }

enum UpdateCheckStatus { idle, checking, current, available, failed }

final appUpdateControllerProvider = ChangeNotifierProvider<AppUpdateController>(
  (ref) => AppUpdateController(automaticDownload: Platform.isWindows),
);

/// One app-scoped check supplies both the About page and its menu badge.
class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    UpdateService? service,
    Future<PackageInfo> Function()? package,
    UpdateTarget? target,
    DateTime Function()? now,
    this.automaticDownload = false,
    this.checkTimeout = const Duration(seconds: 25),
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
  final Duration checkTimeout;
  CancelToken? _attemptCancel;
  UpdateCheckStatus status = UpdateCheckStatus.idle;
  ReleaseUpdate? update;
  DateTime? lastCheckedAt;
  DateTime? _lastAttemptAt;
  String? error;
  Future<void>? _pending;
  bool _disposed = false;

  final bool automaticDownload;
  UpdateDownloadStatus downloadStatus = UpdateDownloadStatus.idle;
  File? downloadedFile;
  ReleaseUpdate? downloadedUpdate;
  int receivedBytes = 0, totalBytes = 0;
  String? downloadError;
  CancelToken? _downloadCancel;
  Future<File?>? _downloadPending;
  Stopwatch? downloadClock;
  bool installing = false;
  int visibleUpdatePages = 0;

  Future<File?> download() {
    if (_disposed || update == null) return Future.value();
    if (_downloadPending != null) return _downloadPending!;
    if (downloadStatus == UpdateDownloadStatus.ready) {
      return Future.value(downloadedFile);
    }
    return _downloadPending = Future<File?>.microtask(
      _download,
    ).whenComplete(() => _downloadPending = null);
  }

  Future<File?> _download() async {
    final candidate = update!;
    final cancel = _downloadCancel = CancelToken();
    downloadStatus = UpdateDownloadStatus.downloading;
    downloadedUpdate = candidate;
    downloadedFile = null;
    downloadError = null;
    downloadClock = Stopwatch()..start();
    receivedBytes = 0;
    totalBytes = candidate.size;
    notifyListeners();
    try {
      // UpdateService.download returns only after its size/SHA256 checks pass.
      final file = await service.download(candidate, cancel, (received, total) {
        if (_disposed || cancel.isCancelled) return;
        receivedBytes = received;
        totalBytes = total;
        notifyListeners();
      });
      if (_disposed || cancel.isCancelled) return null;
      downloadedFile = file;
      downloadStatus = UpdateDownloadStatus.ready;
      notifyListeners();
      return file;
    } catch (failure) {
      if (_disposed) return null;
      downloadStatus = cancel.isCancelled
          ? UpdateDownloadStatus.idle
          : UpdateDownloadStatus.failed;
      downloadError = cancel.isCancelled
          ? null
          : failure is UpdateException
          ? failure.message
          : '下载失败，可在关于中重试';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> cancelDownload() async {
    _downloadCancel?.cancel('取消更新下载');
    try {
      await _downloadPending;
    } catch (_) {
      /* Cancellation is shown by the caller. */
    }
  }

  void discardDownloadedFile() {
    downloadedFile = null;
    downloadStatus = UpdateDownloadStatus.idle;
  }

  Future<InstallLaunch?> installReady(UpdateInstaller installer) async {
    final file = downloadedFile;
    final candidate = downloadedUpdate;
    if (_disposed || installing || file == null || candidate == null) {
      return null;
    }
    installing = true;
    notifyListeners();
    var verified = false;
    try {
      await service.verify(file, candidate);
      verified = true;
      if (!_disposed) return await installer.install(file, candidate.target);
      return null;
    } catch (_) {
      if (!verified) discardDownloadedFile();
      rethrow;
    } finally {
      installing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> check({bool force = false}) {
    if (_disposed ||
        downloadStatus == UpdateDownloadStatus.downloading ||
        installing) {
      return Future.value();
    }
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
    final cancel = _attemptCancel = CancelToken();
    final watch = Stopwatch()..start();
    final opId = AppLog.newOpId();
    var stage = 'package';
    _lastAttemptAt = _now();
    status = UpdateCheckStatus.checking;
    notifyListeners();
    try {
      final package = await _package().timeout(const Duration(seconds: 5));
      if (_disposed) return;
      if (target == null) throw const UpdateException('当前平台请从发布页手动更新');
      if (target == UpdateTarget.android &&
          package.packageName != 'cn.edu.xmu.rollcall.xmu_rollcall') {
        throw const UpdateException('测试版与正式版独立安装，请从发布页获取正式版');
      }
      final version = AppVersion.parse(
        '${package.version}+${package.buildNumber}',
      );
      stage = 'network';
      final result = await service
          .check(version, target!, cancel)
          .timeout(
            checkTimeout,
            onTimeout: () {
              cancel.cancel('检查更新超时');
              throw const UpdateException('检查更新超时，请重试或打开发布页');
            },
          );
      if (_disposed) return;
      if (result?.version.full != update?.version.full) {
        discardDownloadedFile();
        downloadedUpdate = null;
      }
      update = result;
      lastCheckedAt = _now();
      error = null;
      status = result == null
          ? UpdateCheckStatus.current
          : UpdateCheckStatus.available;
      if (automaticDownload &&
          result != null &&
          downloadStatus == UpdateDownloadStatus.idle) {
        unawaited(download().catchError((Object _) => null));
      }
      AppLog.event(
        'update.ui_check.result',
        opId: opId,
        fields: {
          'ok': true,
          'status': status.name,
          'durationMs': watch.elapsedMilliseconds,
        },
      );
    } catch (failure) {
      if (_disposed) return;
      error = failure is UpdateException
          ? failure.message
          : failure is TimeoutException
          ? '读取版本信息超时，请重试'
          : failure is DioException &&
                {
                  DioExceptionType.connectionTimeout,
                  DioExceptionType.receiveTimeout,
                  DioExceptionType.sendTimeout,
                }.contains(failure.type)
          ? '连接更新服务超时，请重试或打开发布页'
          : failure is DioException &&
                failure.type == DioExceptionType.connectionError
          ? '无法连接 GitHub，请检查网络后重试'
          : '暂时无法连接更新服务，请稍后重试或打开发布页。';
      status = UpdateCheckStatus.failed;
      AppLog.event(
        'update.ui_check.result',
        level: 'W',
        opId: opId,
        fields: {
          'ok': false,
          'stage': stage,
          'message': error,
          'durationMs': watch.elapsedMilliseconds,
          'errorType': failure.runtimeType.toString(),
          if (failure is DioException) 'dioType': failure.type.name,
        },
      );
    } finally {
      if (identical(_attemptCancel, cancel)) _attemptCancel = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _downloadCancel?.cancel();
    _attemptCancel?.cancel();
    service.close();
    super.dispose();
  }
}
