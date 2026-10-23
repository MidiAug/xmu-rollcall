import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/update_download_route.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';

extension _CancellationCheck on CancelToken {
  void throwIfCancellationRequested() {
    final error = cancelError;
    if (error != null) throw error;
  }
}

abstract interface class UpdateService {
  Future<ReleaseUpdate?> check(
    AppVersion current,
    UpdateTarget target,
    CancelToken cancel,
  );
  Future<File> download(
    ReleaseUpdate update,
    CancelToken cancel,
    void Function(int, int) progress,
  );
  Future<void> verify(File file, ReleaseUpdate update);
  void close();
}

/// Public GitHub traffic deliberately never shares TronClass's authenticated Dio.
class GithubUpdateService implements UpdateService {
  GithubUpdateService({
    Dio? http,
    Future<Directory> Function()? cacheDirectory,
    Future<Uri?> Function()? downloadMirror,
    this.checkTimeout = const Duration(seconds: 20),
    this.apiTimeout = const Duration(seconds: 7),
  }) : _http =
           http ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 10),
               headers: {
                 'User-Agent': 'xmu-rollcall-updater',
                 'Accept': 'application/vnd.github+json',
               },
             ),
           ),
       _cacheDirectory = cacheDirectory ?? getTemporaryDirectory,
       _downloadMirror = downloadMirror ?? UpdateDownloadRoute.read;
  final Dio _http;
  final Future<Directory> Function() _cacheDirectory;
  final Future<Uri?> Function() _downloadMirror;
  final Duration checkTimeout;
  final Duration apiTimeout;
  static final latest = Uri.parse(
    'https://api.github.com/repos/MidiAug/xmu-rollcall/releases/latest',
  );

  Future<ResponseBody> _open(
    Uri uri,
    CancelToken cancel, {
    bool asset = true,
    String? opId,
    Uri? mirrorUrl,
  }) async {
    for (var redirect = 0; redirect <= 5; redirect++) {
      if (!_allowed(uri, asset: asset) && uri != mirrorUrl) {
        throw const UpdateException('更新地址不受信任，请查看官方发布页');
      }
      final watch = Stopwatch()..start();
      AppLog.event(
        'update.http.start',
        opId: opId,
        fields: {'host': uri.host, 'path': uri.path, 'redirect': redirect},
      );
      late final Response<ResponseBody> response;
      try {
        response = await _http.getUri<ResponseBody>(
          uri,
          cancelToken: cancel,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: false,
            validateStatus: (_) => true,
          ),
        );
      } catch (error) {
        // Do not log exception URI/query or signed storage URLs.
        AppLog.event(
          'update.http.error',
          level: 'W',
          opId: opId,
          fields: {
            'host': uri.host,
            'durationMs': watch.elapsedMilliseconds,
            'errorType': error.runtimeType.toString(),
            if (error is DioException) 'dioType': error.type.name,
          },
        );
        rethrow;
      }
      AppLog.event(
        'update.http.result',
        opId: opId,
        fields: {
          'host': uri.host,
          'status': response.statusCode,
          'durationMs': watch.elapsedMilliseconds,
        },
      );
      final body = response.data!;
      if (response.statusCode == 200) return body;
      await body.stream.listen(null).cancel();
      if ([301, 302, 303, 307, 308].contains(response.statusCode) && asset) {
        final location = response.headers.value('location');
        if (location == null) break;
        uri = uri.resolve(location);
        continue;
      }
      if (response.statusCode == 404) {
        throw const UpdateException('尚无可用的正式更新，或发布文件尚未上传完整', statusCode: 404);
      }
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw UpdateException(
          'GitHub 暂时限制了请求，请稍后重试或打开发布页',
          statusCode: response.statusCode,
        );
      }
      throw UpdateException('更新服务暂不可用，请稍后重试', statusCode: response.statusCode);
    }
    throw const UpdateException('更新下载跳转异常，请查看官方发布页');
  }

  bool _allowed(Uri uri, {required bool asset}) {
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.fragment.isNotEmpty) {
      return false;
    }
    if (!asset) return uri == latest;
    return (uri.host == 'github.com' &&
            (uri.path.startsWith('/MidiAug/xmu-rollcall/releases/download/') ||
                {
                  for (final target in UpdateTarget.values)
                    '/MidiAug/xmu-rollcall/releases/latest/download/manifest-${target.name}.json',
                }.contains(uri.path))) ||
        {
          'release-assets.githubusercontent.com',
          'objects.githubusercontent.com',
        }.contains(uri.host);
  }

  Future<Map<String, dynamic>> _json(
    Uri url,
    CancelToken cancel, {
    bool asset = true,
    int limit = 65536,
    String? opId,
  }) async {
    final body = await _open(url, cancel, asset: asset, opId: opId);
    final bytes = <int>[];
    await for (final chunk in body.stream.timeout(
      const Duration(seconds: 30),
    )) {
      cancel.throwIfCancellationRequested();
      if (bytes.length + chunk.length > limit) {
        throw const UpdateException('更新信息过大，请查看发布页');
      }
      bytes.addAll(chunk);
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const UpdateException('更新信息格式无效');
    }
    return decoded;
  }

  @override
  Future<ReleaseUpdate?> check(
    AppVersion current,
    UpdateTarget target,
    CancelToken cancel,
  ) async {
    final opId = AppLog.newOpId();
    final requestCancel = CancelToken();
    unawaited(cancel.whenCancel.then((error) => requestCancel.cancel(error)));
    cancel.throwIfCancellationRequested();
    final watch = Stopwatch()..start();
    AppLog.event(
      'update.check.start',
      opId: opId,
      fields: {'current': current.full, 'target': target.name},
    );
    try {
      final result = await _check(current, target, requestCancel, opId).timeout(
        checkTimeout,
        onTimeout: () {
          requestCancel.cancel('检查更新达到总时限');
          throw const UpdateException('检查更新超时，请重试或打开发布页');
        },
      );
      AppLog.event(
        'update.check.result',
        opId: opId,
        fields: {
          'ok': true,
          'available': result != null,
          'version': result?.version.full,
          'durationMs': watch.elapsedMilliseconds,
        },
      );
      return result;
    } catch (error) {
      AppLog.event(
        'update.check.result',
        level: 'W',
        opId: opId,
        fields: {
          'ok': false,
          'durationMs': watch.elapsedMilliseconds,
          'errorType': error.runtimeType.toString(),
          if (error is DioException) 'dioType': error.type.name,
          if (error is UpdateException) 'message': error.message,
        },
      );
      rethrow;
    }
  }

  bool _transient(Object error) =>
      error is TimeoutException ||
      (error is UpdateException &&
          (error.statusCode == 403 ||
              error.statusCode == 429 ||
              (error.statusCode ?? 0) >= 500)) ||
      (error is DioException &&
          {
            DioExceptionType.connectionTimeout,
            DioExceptionType.receiveTimeout,
            DioExceptionType.sendTimeout,
            DioExceptionType.connectionError,
          }.contains(error.type));

  Future<ReleaseUpdate?> _check(
    AppVersion current,
    UpdateTarget target,
    CancelToken cancel,
    String opId,
  ) async {
    late final Map<String, dynamic> release;
    final primaryCancel = CancelToken();
    unawaited(cancel.whenCancel.then((error) => primaryCancel.cancel(error)));
    try {
      release =
          await _json(
            latest,
            primaryCancel,
            asset: false,
            limit: 1024 * 1024,
            opId: opId,
          ).timeout(
            apiTimeout,
            onTimeout: () {
              primaryCancel.cancel('更新接口响应超时，改用官方清单');
              throw TimeoutException('GitHub API deadline');
            },
          );
    } catch (error) {
      cancel.throwIfCancellationRequested();
      if (!_transient(error)) rethrow;
      AppLog.event(
        'update.check.fallback',
        opId: opId,
        fields: {
          'reason': error.runtimeType.toString(),
          if (error is UpdateException) 'status': error.statusCode,
        },
      );
      return _checkManifest(current, target, cancel, opId);
    }
    if (release['draft'] != false || release['prerelease'] != false) {
      return null;
    }
    final tag = release['tag_name'];
    if (tag is! String || !tag.startsWith('v')) {
      throw const UpdateException('发布版本格式不受支持');
    }
    final version = AppVersion.parse(tag.substring(1));
    // Tags do not carry build numbers. Never offer a same-version replacement.
    if (version.build != 0) throw const UpdateException('发布标签格式不受支持');
    if (version.compareRelease(current) <= 0) return null;
    final assets = release['assets'];
    if (assets is! List) throw const UpdateException('此版本没有安装包，请查看发布页');
    Map asset(String name, {int limit = 512 * 1024 * 1024}) {
      final matches = assets
          .whereType<Map>()
          .where((a) => a['name'] == name)
          .toList();
      if (matches.length != 1) {
        throw const UpdateException('此版本缺少唯一的安装包或校验清单，请查看发布页');
      }
      final found = matches.single;
      if (found['browser_download_url'] !=
              ReleaseUpdate.assetUrl(version.name, name).toString() ||
          found['state'] != 'uploaded' ||
          found['size'] is! int ||
          found['size'] <= 0 ||
          found['size'] > limit) {
        throw const UpdateException('发布文件信息无效，请查看发布页');
      }
      return found;
    }

    final manifestName = 'manifest-${target.name}.json';
    asset(manifestName, limit: 65536);
    final manifest = await _json(
      ReleaseUpdate.assetUrl(version.name, manifestName),
      cancel,
      opId: opId,
    );
    final template = ReleaseUpdate(
      version: version,
      target: target,
      notes: '',
      size: 0,
      sha256: '',
    );
    final package = asset(template.fileName);
    return _fromManifest(
      manifest,
      current,
      target,
      version: version,
      notes: release['body'] as String? ?? '此版本未提供更新说明。',
      assetSize: package['size'] as int,
      assetDigest: package['digest'] as String?,
    );
  }

  Future<ReleaseUpdate?> _checkManifest(
    AppVersion current,
    UpdateTarget target,
    CancelToken cancel,
    String opId,
  ) async {
    // GitHub's stable latest-download route does not consume REST API quota.
    final manifest = await _json(
      Uri.parse(
        '${ReleaseUpdate.repository}/releases/latest/download/manifest-${target.name}.json',
      ),
      cancel,
      opId: opId,
    );
    final version = AppVersion.parse(manifest['version'] as String? ?? '');
    if (version.compareRelease(current) <= 0) return null;
    return _fromManifest(
      manifest,
      current,
      target,
      version: version,
      notes: '已通过 GitHub 正式发布的校验清单检查。更新接口可能限流或连接异常，请打开发布页查看完整更新说明。',
    );
  }

  ReleaseUpdate _fromManifest(
    Map<String, dynamic> manifest,
    AppVersion current,
    UpdateTarget target, {
    required AppVersion version,
    required String notes,
    int? assetSize,
    String? assetDigest,
  }) {
    final full = AppVersion.parse(manifest['version'] as String? ?? '');
    if (manifest['schemaVersion'] != 1 ||
        full.name != version.name ||
        full.build <= 0 ||
        manifest['platform'] != target.name ||
        manifest['signing'] !=
            (target == UpdateTarget.android ? 'release' : 'unsigned') ||
        !RegExp(
          r'^[a-f0-9]{40}$',
        ).hasMatch(manifest['commit'] as String? ?? '')) {
      throw const UpdateException('更新清单与正式发布不一致，已停止更新');
    }
    if (target == UpdateTarget.android && full.build <= current.build) {
      throw const UpdateException('新版 Android 构建号未递增，请联系维护者');
    }
    final template = ReleaseUpdate(
      version: full,
      target: target,
      notes: '',
      size: 0,
      sha256: '',
    );
    final files = manifest['files'];
    if (files is! List) throw const UpdateException('更新校验清单无效');
    final entries = files
        .whereType<Map>()
        .where((f) => f['name'] == template.fileName)
        .toList();
    if (entries.length != 1 ||
        entries.single['size'] is! int ||
        entries.single['size'] <= 0 ||
        entries.single['size'] > 512 * 1024 * 1024 ||
        (assetSize != null && entries.single['size'] != assetSize) ||
        !RegExp(
          r'^[a-f0-9]{64}$',
        ).hasMatch(entries.single['sha256'] as String? ?? '')) {
      throw const UpdateException('安装包大小或校验值无效');
    }
    final digest = entries.single['sha256'] as String;
    if (assetDigest != null && assetDigest != 'sha256:$digest') {
      throw const UpdateException('GitHub 与发布清单的校验值不一致');
    }
    return ReleaseUpdate(
      version: full,
      target: target,
      notes: notes,
      size: entries.single['size'] as int,
      sha256: digest,
    );
  }

  @override
  Future<File> download(
    ReleaseUpdate update,
    CancelToken cancel,
    void Function(int, int) progress,
  ) async {
    final cache = await _cacheDirectory();
    cancel.throwIfCancellationRequested();
    final folder = await Directory(
      '${cache.path}/updates/${update.version.full}',
    ).create(recursive: true);
    final file = File('${folder.path}/${update.fileName}');
    if (await file.exists()) {
      try {
        await verify(file, update);
        cancel.throwIfCancellationRequested();
        return file;
      } on UpdateException {
        await file.delete();
      }
    }
    final partial = File('${file.path}.part');
    final opId = AppLog.newOpId();
    final watch = Stopwatch()..start();
    final mirror = await _downloadMirror();
    cancel.throwIfCancellationRequested();
    final mirrorUrl = mirror == null
        ? null
        : Uri.parse(
            '${UpdateDownloadRoute.parse(mirror.toString())}${update.downloadUrl}',
          );
    final sources = [?mirrorUrl, update.downloadUrl];
    AppLog.event(
      'update.download.start',
      opId: opId,
      fields: {
        'version': update.version.full,
        'target': update.target.name,
        'size': update.size,
        'host': sources.first.host,
      },
    );
    for (var index = 0; index < sources.length; index++) {
      IOSink? sink;
      var received = 0;
      var lastLogMs = watch.elapsedMilliseconds;
      try {
        if (index > 0) progress(0, update.size);
        final body = await _open(
          sources[index],
          cancel,
          opId: opId,
          mirrorUrl: mirrorUrl,
        );
        sink = partial.openWrite();
        await for (final chunk in body.stream.timeout(
          const Duration(seconds: 30),
        )) {
          cancel.throwIfCancellationRequested();
          received += chunk.length;
          if (received > update.size) {
            throw const UpdateException('安装包大小不符，下载已丢弃');
          }
          sink.add(chunk);
          progress(received, update.size);
          final ms = watch.elapsedMilliseconds;
          if (ms - lastLogMs >= 10000) {
            lastLogMs = ms;
            AppLog.event(
              'update.download.progress',
              opId: opId,
              fields: {
                'received': received,
                'total': update.size,
                'durationMs': ms,
                'source': index,
              },
            );
          }
        }
        await sink.flush();
        await sink.close();
        sink = null;
        cancel.throwIfCancellationRequested();
        await verify(partial, update);
        cancel.throwIfCancellationRequested();
        final complete = await partial.rename(file.path);
        AppLog.event(
          'update.download.result',
          opId: opId,
          fields: {
            'ok': true,
            'received': received,
            'durationMs': watch.elapsedMilliseconds,
            'verified': true,
            'host': sources[index].host,
          },
        );
        return complete;
      } catch (error) {
        final retry =
            !cancel.isCancelled &&
            index + 1 < sources.length &&
            (_transient(error) ||
                error is SocketException ||
                error is HttpException ||
                (error is UpdateException && error.statusCode == 404));
        AppLog.event(
          retry ? 'update.download.fallback' : 'update.download.result',
          level: cancel.isCancelled ? 'I' : 'W',
          opId: opId,
          fields: {
            'ok': false,
            'cancelled': cancel.isCancelled,
            'received': received,
            'durationMs': watch.elapsedMilliseconds,
            'errorType': error.runtimeType.toString(),
            if (error is UpdateException) 'message': error.message,
            if (retry) 'source': 'official',
          },
        );
        if (!retry) rethrow;
      } finally {
        await sink?.close();
        if (await partial.exists()) await partial.delete();
      }
    }
    throw const UpdateException('下载未完成，请重试');
  }

  @override
  Future<void> verify(File file, ReleaseUpdate update) async {
    if (!await file.exists() ||
        await file.length() != update.size ||
        (await crypto.sha256.bind(file.openRead()).first).toString() !=
            update.sha256) {
      throw const UpdateException('安装包校验失败，请重新下载');
    }
  }

  @override
  void close() => _http.close(force: true);
}
