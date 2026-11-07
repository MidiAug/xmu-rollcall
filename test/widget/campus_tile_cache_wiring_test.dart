import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/location/campus_map.dart';
import 'package:xmu_rollcall/features/location/campus_map_config.dart';
import 'package:xmu_rollcall/features/location/campus_tile_cache.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/map_pick_panel.dart';
import 'package:xmu_rollcall/features/rollcall/radar_place_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late BuiltInMapCachingProvider cache;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('campus-cache-wiring-');
    cache = campusTileCache(cacheDirectory: directory.path);
  });
  tearDownAll(() async {
    await cache.destroy();
    await directory.delete(recursive: true);
  });

  final entries = <String, Widget>{
    'campus and saved-location maps': const CampusMap(
      center: kDefaultMapCenter,
    ),
    'coordinate picker': MapPickPanel(onConfirm: (_) {}),
    'radar confirmation preview': const RadarPlaceCard(
      selection: RadarGeoSelection(
        latitude: 24.608429,
        longitude: 118.309669,
        accuracy: 35,
        obtainedVia: RadarObtainedVia.map,
      ),
      onChange: null,
    ),
  };
  for (final entry in entries.entries) {
    testWidgets('${entry.key} uses the shared anonymous tile cache', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: entry.value),
        ),
      );
      final tiles = tester.widgetList<TileLayer>(find.byType(TileLayer));
      expect(tiles, hasLength(1));
      final provider = tiles.single.tileProvider;
      expect(provider, isA<CampusTileProvider>());
      expect((provider as CampusTileProvider).cachingProvider, same(cache));
      expect(tiles.single.urlTemplate, kAmapTileUrlTemplate);
      expect(
        provider.headers.keys.any(
          (k) => ['cookie', 'authorization'].contains(k.toLowerCase()),
        ),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
