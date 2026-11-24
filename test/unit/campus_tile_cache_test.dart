import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/features/location/campus_tile_cache.dart';

// Replace Flutter's test HTTP override with the base loopback-capable client.
class _RealHttp extends HttpOverrides {}

Future<void> _image(NetworkTileProvider provider, TileLayer layer) async {
  final stream = provider
      .getImageWithCancelLoadingSupport(
        const TileCoordinates(1, 2, 3),
        layer,
        Completer<void>().future,
      )
      .resolve(ImageConfiguration.empty);
  final done = Completer<void>();
  final listener = ImageStreamListener(
    (info, _) {
      info.dispose();
      if (!done.isCompleted) done.complete();
    },
    onError: (Object error, StackTrace? stack) {
      if (!done.isCompleted) done.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  try {
    await done.future.timeout(const Duration(seconds: 5));
  } finally {
    stream.removeListener(listener);
  }
}

void _clearImages() {
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late BuiltInMapCachingProvider cache;
  late HttpServer server;
  late int requests;
  late int status;
  late List<HttpHeaders> receivedHeaders;
  late List<NetworkTileProvider> providers;

  TileLayer layer(NetworkTileProvider provider) => TileLayer(
    urlTemplate: 'http://127.0.0.1:${server.port}/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.xmu.rollcall',
    tileProvider: provider,
  );
  String getUrl() => 'http://127.0.0.1:${server.port}/3/1/2.png';
  CampusTileProvider provider() {
    final result = HttpOverrides.runWithHttpOverrides(
      CampusTileProvider.new,
      _RealHttp(),
    );
    providers.add(result);
    return result;
  }

  Future<void> written({String? etag}) async {
    final tile = File(
      '${directory.path}/fm_cache/${BuiltInMapCachingProvider.uuidTileKeyGenerator(getUrl())}',
    );
    final expected =
        30 + (etag?.length ?? 0) + TileProvider.transparentImage.length;
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      if (await tile.exists() && await tile.length() == expected) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Native tile writer did not finish');
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('campus-tile-cache-');
    cache = campusTileCache(cacheDirectory: directory.path);
    providers = [];
    requests = 0;
    status = 200;
    receivedHeaders = [];
    server = await HttpOverrides.runWithHttpOverrides(
      () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      _RealHttp(),
    );
    server.listen((request) async {
      requests++;
      receivedHeaders.add(request.headers);
      request.response.statusCode = status;
      request.response.headers
        ..contentType = ContentType('image', 'png')
        ..set(HttpHeaders.cacheControlHeader, 'max-age=3600')
        ..set(HttpHeaders.ageHeader, '928284')
        ..set(HttpHeaders.dateHeader, HttpDate.format(DateTime.now()));
      request.response.add(
        status == 200 ? TileProvider.transparentImage : [0, 1, 2],
      );
      await request.response.close();
    });
  });
  tearDown(() async {
    for (final p in providers) {
      await p.dispose();
    }
    _clearImages();
    await cache.destroy();
    await server.close(force: true);
    // The library's startup reducer runs in a second isolate; destroy drains
    // the writer, while the reducer may still be releasing its file handles.
    for (var attempt = 0; ; attempt++) {
      try {
        await directory.delete(recursive: true);
        break;
      } on FileSystemException {
        if (attempt == 20) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  });

  test(
    'default HTTP freshness reproduces a second GET for aged CDN tiles',
    () async {
      await cache.destroy();
      cache = BuiltInMapCachingProvider.getOrCreateInstance(
        cacheDirectory: directory.path,
      );
      final first = HttpOverrides.runWithHttpOverrides(
        NetworkTileProvider.new,
        _RealHttp(),
      );
      providers.add(first);
      await _image(first, layer(first));
      await written();
      await cache.destroy();
      _clearImages();
      cache = BuiltInMapCachingProvider.getOrCreateInstance(
        cacheDirectory: directory.path,
      );
      expect((await cache.getTile(getUrl()))!.metadata.isStale, isTrue);
      final reopened = HttpOverrides.runWithHttpOverrides(
        NetworkTileProvider.new,
        _RealHttp(),
      );
      providers.add(reopened);
      await _image(reopened, layer(reopened));
      expect(requests, 2);
    },
  );

  test(
    'viewed tile survives provider reopen and disk cache restart without GET',
    () async {
      final first = provider();
      await _image(first, layer(first));
      expect(requests, 1);
      // Destroy drains the native writer; do not confuse Flutter's decoded-image
      // cache with disk reuse, and recreate the real disk provider from its files.
      await cache.destroy();
      _clearImages();
      cache = campusTileCache(cacheDirectory: directory.path);
      final stored = await cache.getTile(getUrl());
      expect(stored, isNotNull);
      expect(stored!.metadata.isStale, isFalse);
      expect(
        stored.metadata.staleAt.difference(DateTime.now()).inHours,
        inInclusiveRange(7 * 24 - 1, 7 * 24),
      );
      final reopened = provider();
      await _image(reopened, layer(reopened));
      expect(requests, 1);
      for (final headers in receivedHeaders) {
        expect(headers.value(HttpHeaders.cookieHeader), isNull);
        expect(headers.value(HttpHeaders.authorizationHeader), isNull);
      }
    },
  );

  test('expired tile revalidates and failed download remains an error', () async {
    final first = provider();
    await _image(first, layer(first));
    await written();
    await cache.destroy();
    _clearImages();
    // A previous session's expired metadata is read through the real file format.
    cache = BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: directory.path,
      maxCacheSize: campusTileCacheMaxBytes,
    );
    await cache.putTile(
      url: getUrl(),
      metadata: CachedMapTileMetadata(
        staleAt: DateTime.now().subtract(const Duration(seconds: 1)),
        lastModified: null,
        etag: '"old-tile"',
      ),
      bytes: TileProvider.transparentImage,
    );
    await written(etag: '"old-tile"');
    await cache.destroy();
    cache = campusTileCache(cacheDirectory: directory.path);
    _clearImages();
    status = 404;
    final retry = provider();
    await expectLater(
      _image(retry, layer(retry)),
      throwsA(isA<NetworkImageLoadException>()),
    );
    expect(requests, 2);
    expect(
      receivedHeaders.last.value(HttpHeaders.ifNoneMatchHeader),
      '"old-tile"',
    );
    expect((await cache.getTile(getUrl()))!.metadata.isStale, isTrue);
    status = 200;
    _clearImages();
    await _image(retry, layer(retry));
    expect(requests, 3);
    await written();
    await cache.destroy();
    cache = campusTileCache(cacheDirectory: directory.path);
    expect((await cache.getTile(getUrl()))!.metadata.isStale, isFalse);
  });

  test(
    'same visible tile requested concurrently shares the image request',
    () async {
      final first = provider();
      final second = provider();
      await Future.wait([
        _image(first, layer(first)),
        _image(second, layer(second)),
      ]);
      expect(requests, 1);
      await cache.destroy();
      cache = campusTileCache(cacheDirectory: directory.path);
      expect(await cache.getTile(getUrl()), isNotNull);
      expect(await cache.getTile('${getUrl()}-not-viewed'), isNull);
    },
  );

  test(
    'startup applies 64 MiB soft budget to the isolated cache directory',
    () async {
      await cache.destroy();
      final oversized = File('${directory.path}/fm_cache/old-tile');
      final file = await oversized.open(mode: FileMode.write);
      await file.truncate(campusTileCacheMaxBytes + 1);
      await file.close();
      cache = campusTileCache(cacheDirectory: directory.path);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (await oversized.exists() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(await oversized.exists(), isFalse);
    },
  );

  test(
    'campusTileKeyGenerator normalizes AMap subdomains while keeping coordinates distinct',
    () {
      const base =
          'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&ltype=11&x=54321&y=28123&z=16';
      const sub3 =
          'https://webrd03.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&ltype=11&x=54321&y=28123&z=16';
      const otherTile =
          'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&ltype=11&x=54322&y=28123&z=16';
      const otherZoom =
          'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&ltype=11&x=54321&y=28123&z=17';
      expect(campusTileKeyGenerator(sub3), campusTileKeyGenerator(base));
      expect(campusTileKeyGenerator(otherTile), isNot(campusTileKeyGenerator(base)));
      expect(campusTileKeyGenerator(otherZoom), isNot(campusTileKeyGenerator(base)));
    },
  );
}
