import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/github_update_service.dart';

class Adapter implements HttpClientAdapter {
  Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory cache;
  late Map<String, dynamic> release;
  late Map<String, dynamic> manifest;
  late GithubUpdateService service;
  late Adapter adapter;
  final bytes = utf8.encode('synthetic installer fixture');
  final digest = sha256.convert(bytes).toString();
  const package = 'xmu-rollcall-0.2.0-android.apk';
  Map<String, dynamic> asset(String name, int size) => {
    'name': name,
    'state': 'uploaded',
    'size': size,
    'browser_download_url': ReleaseUpdate.assetUrl('0.2.0', name).toString(),
  };
  ResponseBody json(Object value) =>
      ResponseBody.fromString(jsonEncode(value), 200);
  Future<ReleaseUpdate?> check({
    AppVersion current = const AppVersion(0, 1, 1, 2),
    UpdateTarget target = UpdateTarget.android,
  }) => service.check(current, target, CancelToken());
  setUp(() async {
    cache = await Directory.systemTemp.createTemp('xmu-updater-test-');
    release = {
      'tag_name': 'v0.2.0',
      'draft': false,
      'prerelease': false,
      'body': 'Added a fixture',
      'assets': [
        asset('manifest-android.json', 1000),
        asset(package, bytes.length),
      ],
    };
    manifest = {
      'schemaVersion': 1,
      'version': '0.2.0+3',
      'commit': 'a' * 40,
      'platform': 'android',
      'signing': 'release',
      'files': [
        {'name': package, 'size': bytes.length, 'sha256': digest},
      ],
    };
    adapter = Adapter((request) async {
      if (request.uri == GithubUpdateService.latest) return json(release);
      if (request.path.endsWith('.json')) return json(manifest);
      return ResponseBody.fromBytes(bytes, 200);
    });
    service = GithubUpdateService(
      http: Dio()..httpClientAdapter = adapter,
      cacheDirectory: () async => cache,
    );
  });
  tearDown(() async {
    service.close();
    await cache.delete(recursive: true);
  });

  test(
    'stable versions compare numerically; unsupported tags are rejected',
    () {
      expect(
        AppVersion.parse('0.10.0+3').compareTo(AppVersion.parse('0.9.9+5')),
        greaterThan(0),
      );
      expect(
        AppVersion.parse('0.2.0+4').compareTo(AppVersion.parse('0.2.0+3')),
        greaterThan(0),
      );
      for (final value in ['v0.2.0', '0.2.0-beta', '../0.2.0', '0.02.0']) {
        expect(() => AppVersion.parse(value), throwsA(isA<UpdateException>()));
      }
    },
  );
  test(
    'latest stable release and manifest identify the exact Android package',
    () async {
      final update = (await check())!;
      expect(update.version.full, '0.2.0+3');
      expect(update.notes, 'Added a fixture');
      expect(update.fileName, package);
      expect(update.sha256, digest);
      expect(adapter.requests, hasLength(2));
      for (final request in adapter.requests) {
        expect(
          request.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(
          request.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('cookie')),
        );
        expect(request.followRedirects, false);
      }
    },
  );
  test(
    'same or older release, drafts and prereleases never offer an update',
    () async {
      for (final current in [
        const AppVersion(0, 2, 0, 1),
        const AppVersion(1, 0, 0),
      ]) {
        expect(await check(current: current), isNull);
      }
      for (final key in ['draft', 'prerelease']) {
        release[key] = true;
        expect(await check(), isNull);
        release[key] = false;
      }
      expect(
        adapter.requests.every(
          (request) => request.uri == GithubUpdateService.latest,
        ),
        true,
      );
    },
  );
  test('Windows chooses the installer rather than the portable ZIP', () async {
    const installer = 'xmu-rollcall-0.2.0-windows-x64-setup.exe';
    release['assets'] = [
      asset('manifest-windows.json', 1000),
      asset(installer, bytes.length),
      asset('xmu-rollcall-0.2.0-windows-x64.zip', 20),
    ];
    manifest.addAll({
      'platform': 'windows',
      'signing': 'unsigned',
      'files': [
        {'name': installer, 'size': bytes.length, 'sha256': digest},
      ],
    });
    expect((await check(target: UpdateTarget.windows))!.fileName, installer);
  });
  test(
    'preview, mismatched release and non-increasing Android build are blocked',
    () async {
      for (final mutation in [
        {'signing': 'preview'},
        {'platform': 'windows'},
        {'version': '0.3.0+4'},
        {'version': '0.2.0+2'},
        {'commit': 'invalid'},
        {'schemaVersion': 2},
      ]) {
        final original = Map<String, dynamic>.from(manifest);
        manifest.addAll(mutation);
        await expectLater(check(), throwsA(isA<UpdateException>()));
        manifest = original;
      }
    },
  );
  test(
    'missing/duplicate assets, external URLs and size/digest disagreement are blocked',
    () async {
      final original = List<Map<String, dynamic>>.from(
        release['assets'] as List,
      );
      for (final assets in [
        [original.first],
        [...original, original.last],
        [
          original.first,
          {
            ...original.last,
            'browser_download_url': 'https://example.com/update.apk',
          },
        ],
        [
          original.first,
          {...original.last, 'size': bytes.length + 1},
        ],
        [
          original.first,
          {...original.last, 'digest': 'sha256:${'0' * 64}'},
        ],
      ]) {
        release['assets'] = assets;
        await expectLater(check(), throwsA(isA<UpdateException>()));
      }
    },
  );
  test(
    'download verifies bytes, reuses verified cache and detects later tampering',
    () async {
      final update = (await check())!;
      final progress = <int>[];
      final file = await service.download(
        update,
        CancelToken(),
        (received, _) => progress.add(received),
      );
      expect(await file.readAsBytes(), bytes);
      expect(progress.last, bytes.length);
      final requests = adapter.requests.length;
      expect(
        (await service.download(update, CancelToken(), (_, _) {})).path,
        file.path,
      );
      expect(adapter.requests.length, requests);
      await file.writeAsBytes(List.filled(bytes.length, 0));
      await expectLater(
        service.verify(file, update),
        throwsA(isA<UpdateException>()),
      );
      await service.download(update, CancelToken(), (_, _) {});
      expect(await file.readAsBytes(), bytes);
    },
  );
  test(
    'truncated, oversized and corrupt downloads leave no installable or partial file',
    () async {
      final update = (await check())!;
      for (final content in [
        bytes.sublist(1),
        [...bytes, 0],
        List.filled(bytes.length, 0),
      ]) {
        adapter = Adapter((_) async => ResponseBody.fromBytes(content, 200));
        service.close();
        service = GithubUpdateService(
          http: Dio()..httpClientAdapter = adapter,
          cacheDirectory: () async => cache,
        );
        await expectLater(
          service.download(update, CancelToken(), (_, _) {}),
          throwsA(isA<UpdateException>()),
        );
        expect(cache.listSync(recursive: true).whereType<File>(), isEmpty);
      }
    },
  );
  test(
    'cancelling after receiving bytes removes the partial download',
    () async {
      final update = (await check())!;
      final cancel = CancelToken();
      await expectLater(
        service.download(update, cancel, (_, _) => cancel.cancel()),
        throwsA(isA<DioException>()),
      );
      expect(cache.listSync(recursive: true).whereType<File>(), isEmpty);
    },
  );
  test('only official HTTPS asset redirects are followed', () async {
    final update = (await check())!;
    for (final location in [
      'https://example.com/file',
      'http://release-assets.githubusercontent.com/file',
      'https://github.com/other/repo/releases/download/v0.2.0/file',
    ]) {
      adapter = Adapter(
        (_) async => ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': [location],
          },
        ),
      );
      service.close();
      service = GithubUpdateService(
        http: Dio()..httpClientAdapter = adapter,
        cacheDirectory: () async => cache,
      );
      await expectLater(
        service.download(update, CancelToken(), (_, _) {}),
        throwsA(isA<UpdateException>()),
      );
      expect(adapter.requests, hasLength(1));
    }
    adapter = Adapter(
      (request) async => request.uri.host == 'github.com'
          ? ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': [
                  'https://release-assets.githubusercontent.com/file?token=fixture',
                ],
              },
            )
          : ResponseBody.fromBytes(bytes, 200),
    );
    service.close();
    service = GithubUpdateService(
      http: Dio()..httpClientAdapter = adapter,
      cacheDirectory: () async => cache,
    );
    await service.download(update, CancelToken(), (_, _) {});
    expect(adapter.requests, hasLength(2));
  });
  test(
    'missing releases and repeated rate limiting fail with bounded requests',
    () async {
      for (final status in [404, 403, 429]) {
        adapter = Adapter((_) async => ResponseBody.fromString('', status));
        service.close();
        service = GithubUpdateService(http: Dio()..httpClientAdapter = adapter);
        await expectLater(
          check(),
          throwsA(
            isA<UpdateException>().having(
              (e) => e.message,
              'message',
              contains(status == 404 ? '正式更新' : '稍后重试'),
            ),
          ),
        );
        expect(adapter.requests, hasLength(status == 404 ? 1 : 2));
      }
    },
  );
  test(
    'REST quota fallback uses the stable release manifest with identical checks',
    () async {
      for (final status in [403, 429]) {
        adapter = Adapter(
          (request) async => request.uri == GithubUpdateService.latest
              ? ResponseBody.fromString('', status)
              : json(manifest),
        );
        service.close();
        service = GithubUpdateService(http: Dio()..httpClientAdapter = adapter);
        final result = (await check())!;
        expect(result.fileName, package);
        expect(result.sha256, digest);
        expect(result.notes, contains('限流'));
        expect(
          adapter.requests.last.path,
          contains('/releases/latest/download/manifest-android.json'),
        );
        expect(adapter.requests, hasLength(2));
        manifest['signing'] = 'preview';
        await expectLater(check(), throwsA(isA<UpdateException>()));
        manifest['signing'] = 'release';
      }
    },
  );
}
