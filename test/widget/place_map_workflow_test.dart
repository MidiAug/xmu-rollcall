import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/features/campus/campus_summary_providers.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/campus_map.dart';
import 'package:xmu_rollcall/features/location/saved_locations_page.dart';
import 'package:xmu_rollcall/features/location/place_providers.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/features/rollcall/session_block.dart';
import 'package:xmu_rollcall/features/settings/timetable_grid_view.dart';
import '../fixtures/preview_fonts.dart';

Future<void> capture(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  if (Platform.environment['CAPTURE_PLACE_UI'] != '1') return;
  await tester.runAsync(() async {
    final render = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('place-capture')),
    );
    final image = await render.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await Directory(
      'build/place-ui-review',
    ).create(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => (await Directory(
            'build/map-test-cache',
          ).create(recursive: true)).absolute.path,
        );
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (Platform.environment['CAPTURE_PLACE_UI'] == '1') {
      await loadDesktopPreviewFonts();
      await (FontLoader('MaterialIcons')..addFont(
            File(
              'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });
  for (final width in [384.0, 960.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'map completion and read-only homework at $width dark=$dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final scope = ProviderContainer(
            overrides: [
              campusCachedDataProvider.overrideWith(
                (ref) async => const CampusCachedData(),
              ),
              courseRoomsProvider.overrideWithValue([
                '学武楼（1号楼）C201',
                '西部片区9号楼108',
              ]),
              homeworkDetailProvider.overrideWith(
                (ref, key) async => HomeworkItem(
                  id: 1,
                  title: '第四周作业：程序设计基础',
                  courseName: 'C语言程序设计',
                  courseId: 3,
                  dueAt: DateTime(2026, 10, 29),
                  description: '<p>完成课本第四章练习，说明解题思路。</p><p>请阅读附件中的格式要求。</p>',
                  attachments: [
                    HomeworkAttachment(
                      name: '第四章练习.pdf',
                      size: 20480,
                      url: Uri.parse('https://lnt.xmu.edu.cn/example.pdf'),
                    ),
                  ],
                ),
              ),
            ],
          );
          addTearDown(scope.dispose);
          final theme = (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
            platform: width < 600
                ? TargetPlatform.android
                : TargetPlatform.windows,
          );
          Future<void> show(Widget body) async {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: scope,
                child: MaterialApp(
                  theme: theme,
                  home: RepaintBoundary(
                    key: const ValueKey('place-capture'),
                    child: body,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          await show(const SavedLocationsPage());
          expect(scope.read(preferredCampusProvider), Campus.xiangan);
          expect(find.text('待补全（1）'), findsOneWidget);
          if (width >= 720) {
            expect(find.byType(CampusSelector), findsOneWidget);
            expect(
              tester.getTopLeft(find.byType(CampusSelector)).dy,
              lessThan(
                tester
                    .getTopLeft(
                      find.byKey(const ValueKey('managed-room-西部片区9号楼')),
                    )
                    .dy,
              ),
            );
          } else {
            expect(find.byType(DropdownButton<Campus>), findsOneWidget);
          }
          await tester.tap(find.byTooltip('只看待补全'));
          await tester.pumpAndSettle();
          final filter = tester.widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.filter_list),
          );
          expect(filter.isSelected, isTrue);
          expect(
            filter.style?.backgroundColor?.resolve({}),
            isNot(Colors.transparent),
          );
          await tester.tap(find.byTooltip('显示全部地点'));
          await tester.pumpAndSettle();
          final tabs = find.byType(AppSegmentedControl<bool>);
          final marker = find.descendant(
            of: tabs,
            matching: find.byType(FractionallySizedBox),
          );
          final tabsWidth = tester.getSize(tabs).width;
          expect(
            tester.getCenter(marker).dx,
            closeTo(tester.getCenter(find.text('课程地点')).dx, 1),
          );
          await tester.tap(find.text('我的地点'));
          await tester.pumpAndSettle();
          expect(
            tester.getCenter(marker).dx,
            closeTo(tester.getCenter(find.text('我的地点')).dx, 1),
          );
          expect(tester.getSize(tabs).width, tabsWidth);
          await tester.tap(find.text('课程地点'));
          await tester.pumpAndSettle();
          expect(
            tester
                .getSize(find.byKey(const ValueKey('managed-room-西部片区9号楼')))
                .height,
            lessThanOrEqualTo(60),
          );
          await capture(tester, 'map-$width-$dark');
          await tester.tap(find.byKey(const ValueKey('managed-room-西部片区9号楼')));
          await tester.pumpAndSettle();
          await capture(tester, 'map-edit-$width-$dark');
          final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
          map.options.onTap!(
            const TapPosition(Offset.zero, Offset.zero),
            const LatLng(24.606, 118.30),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('保存地点'));
          await tester.tap(find.text('保存地点'));
          await tester.pumpAndSettle();
          expect(scope.read(unmatchedRoomsProvider), isEmpty);
          expect(scope.read(savedLocationsProvider).single.note, '西部片区9号楼');
          await capture(tester, 'map-saved-$width-$dark');
          await show(
            const HomeworkDetailPage(seed: HomeworkItem(id: 1, title: '作业')),
          );
          expect(find.text('第四章练习.pdf'), findsOneWidget);
          expect(find.byTooltip('下载附件'), findsOneWidget);
          await capture(tester, 'homework-$width-$dark');
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'building overview expands regions while a region keeps exact coordinates',
    (tester) async {
      tester.view.physicalSize = const Size(960, 900);
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
            courseRoomsProvider.overrideWithValue(const []),
          ],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            home: const RepaintBoundary(
              key: ValueKey('place-capture'),
              child: SavedLocationsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('managed-room-学武楼')), findsOneWidget);
      expect(find.byKey(const ValueKey('managed-room-学武楼 A区')), findsNothing);
      expect(find.text('A区'), findsNothing);
      await capture(tester, 'building-overview');
      await tester.tap(find.byKey(const ValueKey('managed-room-学武楼')));
      await tester.pumpAndSettle();
      final inspector = find.byKey(const ValueKey('map-building-inspector'));
      expect(inspector, findsOneWidget);
      expect(find.byKey(const ValueKey('managed-wing-学武楼 A区')), findsOneWidget);
      await tester.tap(
        find.descendant(of: inspector, matching: find.byTooltip('关闭')),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      controller.move(const LatLng(24.605494, 118.313825), 18.3);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('map-place-学武楼 B区')), findsOneWidget);
      expect(find.byKey(const ValueKey('map-building-学武楼')), findsNothing);
      await capture(tester, 'building-expanded');
      final before = controller.camera;
      await tester.tap(find.byKey(const ValueKey('map-place-学武楼 B区')));
      await tester.pumpAndSettle();
      expect(controller.camera.center, before.center);
      expect(controller.camera.zoom, before.zoom);
      expect(find.text('24.605494, 118.313825'), findsOneWidget);
      expect(find.text('内置教学区域，按课程教室匹配'), findsOneWidget);
      await capture(tester, 'building-region-selected');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'map controls consume taps and a draft preserves pan, zoom and equal insets',
    (tester) async {
      tester.view.physicalSize = const Size(960, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusCachedDataProvider.overrideWith(
              (ref) async => const CampusCachedData(),
            ),
            courseRoomsProvider.overrideWithValue(const []),
          ],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            home: const RepaintBoundary(
              key: ValueKey('place-capture'),
              child: SavedLocationsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mapFinder = find.byType(CampusMap);
      final mapRect = tester.getRect(mapFinder);
      final hint = tester.getRect(find.byKey(const ValueKey('map-idle-hint')));
      expect(hint.left - mapRect.left, closeTo(12, .1));
      expect(mapRect.bottom - hint.bottom, closeTo(12, .1));
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      controller.move(const LatLng(24.6068, 118.3118), 20);
      await tester.pumpAndSettle();
      final before = controller.camera;
      expect(
        tester.widget<TileLayer>(find.byType(TileLayer)).maxNativeZoom,
        18,
      );
      expect(before.zoom, 20);
      await tester.tap(find.byTooltip('地图来源'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('map-attribution-panel')),
        findsOneWidget,
      );
      expect(tester.widget<CampusMap>(mapFinder).point, isNull);
      final controls = tester.getRect(find.byType(MapAttributionControls));
      expect(controls.top - mapRect.top, closeTo(12, .1));
      expect(mapRect.right - controls.right, closeTo(12, .1));
      await tester.tap(find.byTooltip('flutter_map'));
      await tester.pumpAndSettle();
      expect(tester.widget<CampusMap>(mapFinder).point, isNull);
      expect(find.byKey(const ValueKey('map-attribution-panel')), findsNothing);
      await tester.tapAt(mapRect.topLeft + const Offset(100, 140));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final point = tester.widget<CampusMap>(mapFinder).point!;
      final after = controller.camera;
      expect(after.center.latitude, closeTo(before.center.latitude, 1e-10));
      expect(after.center.longitude, closeTo(before.center.longitude, 1e-10));
      expect(after.zoom, before.zoom);
      final inspector = tester.getRect(
        find.byKey(const ValueKey('map-place-inspector')),
      );
      expect(mapRect.right - inspector.right, closeTo(12, .1));
      expect(mapRect.bottom - inspector.bottom, closeTo(12, .1));
      final coordinates = tester.widget<SelectableText>(
        find.byKey(const ValueKey('managed-place-coordinates')),
      );
      expect(
        coordinates.data,
        '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
      );
      await tester.tap(find.byTooltip('地图来源'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-attribution-panel')));
      await tester.pumpAndSettle();
      expect(tester.widget<CampusMap>(mapFinder).point, point);
      expect(controller.camera.center, after.center);
      expect(controller.camera.zoom, after.zoom);
      await capture(tester, 'map-viewport-draft');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'academic course opens and returns from a map within one dialog',
    (tester) async {
      tester.view.physicalSize = const Size(960, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final course = CatalogCourse(
        id: 'academic:test',
        title: '课程示例',
        location: '学武楼C201',
        timetables: {
          1: [
            TimetableSlot(
              sequence: 5,
              endSequence: 6,
              start: DateTime(2000, 1, 1, 14, 30),
              end: DateTime(2000, 1, 1, 16, 10),
              classroom: '学武楼C201',
            ),
          ],
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            campusCachedDataProvider.overrideWith(
              (ref) async => const CampusCachedData(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: TimetableGridView(courses: [course])),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('课程示例').first);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      final flow = find.byKey(const ValueKey('course-detail-flow'));
      final compactHeight = tester.getSize(flow).height;
      expect(
        tester
            .getSize(find.byKey(const ValueKey('course-location-map-link')))
            .height,
        lessThan(40),
      );
      await tester.tap(find.byKey(const ValueKey('course-location-map-link')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final expandingHeight = tester.getSize(flow).height;
      await tester.pumpAndSettle();
      final mapHeight = tester.getSize(flow).height;
      expect(expandingHeight, greaterThan(compactHeight));
      expect(expandingHeight, lessThan(mapHeight));
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(CampusMap), findsOneWidget);
      expect(find.byType(CampusSelector), findsNothing);
      final map = tester.widget<CampusMap>(find.byType(CampusMap));
      expect(map.places, isEmpty);
      expect(map.point, isNotNull);
      await tester.tap(find.byTooltip('返回课程'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final collapsingHeight = tester.getSize(flow).height;
      expect(collapsingHeight, lessThan(mapHeight));
      expect(collapsingHeight, greaterThan(compactHeight));
      await tester.pumpAndSettle();
      expect(find.byType(CampusMap), findsNothing);
      expect(find.byTooltip('关闭课程详情'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
