import 'package:flutter_map/flutter_map.dart';

const campusTileCacheMaxBytes = 64 * 1024 * 1024;
const campusTileFreshAge = Duration(days: 7);

final _amapSubdomainPattern = RegExp(r'webrd0[1-4]\.is\.autonavi\.com');

String campusTileKeyGenerator(String url) =>
    BuiltInMapCachingProvider.uuidTileKeyGenerator(
      url.replaceFirst(_amapSubdomainPattern, 'webrd01.is.autonavi.com'),
    );

/// Policy for the current public AMap basemap, not a general HTTP cache.
/// flutter_map does not fully interpret no-store/no-cache/private directives;
/// the verified AMap response only had max-age. Recheck before changing sources.
/// No account client, cookies or location records.
/// flutter_map applies this soft byte budget at cache startup, not each write.
BuiltInMapCachingProvider campusTileCache({
  String? cacheDirectory,
}) => BuiltInMapCachingProvider.getOrCreateInstance(
  cacheDirectory: cacheDirectory,
  maxCacheSize: campusTileCacheMaxBytes,
  tileKeyGenerator: campusTileKeyGenerator,
  // The tile CDN can return Age greater than max-age without validators.
  // Reuse viewed imagery for seven days rather than refetching on every reopen.
  overrideFreshAge: campusTileFreshAge,
);

/// Keep the standard tile HTTP lifecycle, cancellation, errors and image cache.
/// Lazy configuration matches NetworkTileProvider: no disk work before a tile
/// is actually requested, and every map entry uses the same native disk cache.
class CampusTileProvider extends NetworkTileProvider {
  @override
  MapCachingProvider get cachingProvider => campusTileCache();
}
