import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/location/campus_map.dart';
import 'package:xmu_rollcall/features/location/campus_map_config.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/place_providers.dart';
import 'package:xmu_rollcall/features/location/saved_locations_page.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> open(WidgetTester tester, List<CoursePlaceGroup> groups) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          campusCachedDataProvider.overrideWith(
            (ref) async => const CampusCachedData(),
          ),
          preferredCampusProvider.overrideWithValue(Campus.xiangan),
          coursePlaceGroupsProvider.overrideWithValue(groups),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SavedLocationsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'course map contains only matched timetable regions in the selected campus',
    (tester) async {
      await open(tester, const [
        CoursePlaceGroup('学武楼 A区', ['学武楼A101'], ['课程一']),
        CoursePlaceGroup('学武楼 C区', ['学武楼C201'], ['课程二']),
        CoursePlaceGroup('海韵教学楼', ['海韵教学楼202'], ['其他校区课程']),
      ]);
      final map = tester.widget<CampusMap>(find.byType(CampusMap));
      expect(map.places.map((p) => p.id).toSet(), {
        'xmu:teaching:xuewu-a',
        'xmu:teaching:xuewu-c',
      });
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final before = tester
          .widgetList<MarkerLayer>(find.byType(MarkerLayer))
          .first
          .markers;
      controller.move(const LatLng(24.606, 118.312), 16);
      await tester.pump();
      final after = tester
          .widgetList<MarkerLayer>(find.byType(MarkerLayer))
          .first
          .markers;
      expect(
        identical(before, after),
        isTrue,
        reason:
            'Panning reuses marker descriptions instead of deriving the catalog again',
      );
      controller.move(const LatLng(30, 130), 16);
      await tester.pump();
      expect(kXmuMapBounds.contains(controller.camera.center), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an empty timetable does not expose unrelated presets on the map',
    (tester) async {
      await open(tester, const []);
      expect(tester.widget<CampusMap>(find.byType(CampusMap)).places, isEmpty);
      expect(find.text('本校区暂无课程地点'), findsOneWidget);
    },
  );
}
