import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/github_update_service.dart';
import 'package:xmu_rollcall/platform/app_update_installer.dart';

class FakeUpdateService implements UpdateService {
  ReleaseUpdate? result;
  Object? checkError;
  Object? verifyError;
  Completer<ReleaseUpdate?>? pendingCheck;
  Completer<File>? pendingDownload;
  CancelToken? checkCancel;
  CancelToken? downloadCancel;
  int checks = 0;
  int downloads = 0;
  int verifications = 0;
  bool closed = false;
  @override
  Future<ReleaseUpdate?> check(
    AppVersion current,
    UpdateTarget target,
    CancelToken cancel,
  ) async {
    checks++;
    checkCancel = cancel;
    if (checkError != null) throw checkError!;
    return pendingCheck?.future ?? result;
  }

  @override
  Future<File> download(
    ReleaseUpdate update,
    CancelToken cancel,
    void Function(int, int) progress,
  ) async {
    downloads++;
    downloadCancel = cancel;
    progress(update.size ~/ 2, update.size);
    if (pendingDownload != null) {
      return Future.any([
        pendingDownload!.future,
        cancel.whenCancel.then<File>((error) => throw error),
      ]);
    }
    progress(update.size, update.size);
    return File('fixture-installer');
  }

  @override
  Future<void> verify(File file, ReleaseUpdate update) async {
    verifications++;
    if (verifyError != null) throw verifyError!;
  }

  @override
  void close() {
    closed = true;
  }
}

class FakeUpdateInstaller implements UpdateInstaller {
  int calls = 0;
  InstallLaunch result = InstallLaunch.launched;
  Object? error;
  @override
  Future<InstallLaunch> install(File file, UpdateTarget target) async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
}
