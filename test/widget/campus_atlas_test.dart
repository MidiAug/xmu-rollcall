import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/campus/campus_tools_page.dart';
import 'package:xmu_rollcall/features/campus/campus_search_index.dart';
import 'package:xmu_rollcall/features/location/campus_atlas_page.dart';
import 'package:xmu_rollcall/features/location/campus_map.dart';
import 'package:xmu_rollcall/features/location/campus_map_config.dart';
import 'package:xmu_rollcall/features/location/teaching_catalog.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/place_matching.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/campus_stories.dart';
import 'package:xmu_rollcall/features/location/campus_story_dialog.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    final material = File(
      'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
    if (material.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(material.readAsBytes().then(ByteData.sublistView))).load();
    }
    final faces = ['regular', 'medium', 'bold']
        .map(
          (face) => File(
            'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/roboto-$face.ttf',
          ),
        )
        .where((file) => file.existsSync())
        .toList();
    if (faces.isNotEmpty) {
      final roboto = FontLoader('Roboto');
      for (final file in faces) {
        roboto.addFont(file.readAsBytes().then(ByteData.sublistView));
      }
      await roboto.load();
    }
    final cache = await Directory(
      'build/campus-atlas-cache',
    ).create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.absolute.path,
        );
  });
  testWidgets(
    'label collisions keep selection and reveal nearby labels when zooming',
    (tester) async {
      final controller = MapController();
      addTearDown(controller.dispose);
      SavedLocation place(String id, double latitude) => SavedLocation(
        id: id,
        note: '测试楼宇$id',
        latitude: latitude,
        longitude: 118.3115,
        createdAt: DateTime(2026, 11, 3),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CampusMap(
              center: const LatLng(24.6045, 118.3115),
              controller: controller,
              showPlaceLabels: true,
              avoidLabelOverlap: true,
              selectedPlaceId: 'selected',
              places: [
                place('duplicate', 24.6045),
                place('nearby', 24.6049),
                place('selected', 24.6045),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      List<Marker> markers() => tester
          .widgetList<MarkerLayer>(find.byType(MarkerLayer))
          .expand((layer) => layer.markers)
          .toList();
      expect(
        markers().map((m) => m.key),
        contains(const ValueKey('map-marker-selected')),
      );
      expect(
        markers().map((m) => m.key),
        isNot(contains(const ValueKey('map-marker-nearby'))),
      );
      controller.move(controller.camera.center, 19.2);
      await tester.pumpAndSettle();
      expect(
        markers().map((m) => m.key),
        contains(const ValueKey('map-marker-nearby')),
      );
      final rects = markers()
          .map(
            (m) => Rect.fromCenter(
              center: controller.camera.latLngToScreenOffset(m.point),
              width: m.width,
              height: m.height,
            ).inflate(4),
          )
          .toList();
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse);
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final dark in [false, true]) {
    testWidgets('desktop directory and zoom levels stay in sync dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
            platform: TargetPlatform.windows,
          ),
          builder: (_, child) => RepaintBoundary(key: capture, child: child),
          home: const CampusAtlasPage(),
        ),
      );
      await tester.pumpAndSettle();
      CampusMap map() => tester.widget<CampusMap>(find.byType(CampusMap));
      expect(find.text('独立楼宇与待核地点'), findsNothing);
      expect(
        find.byKey(const ValueKey('atlas-group-independent-翔安')),
        findsNothing,
      );
      expect(find.text('49 栋楼宇'), findsOneWidget); // map badge only
      expect(map().places.any((p) => p.id.contains('independent-')), isFalse);
      expect(
        map().places.where((p) => !p.id.startsWith('atlas-group:')),
        isNotEmpty,
      );
      final row = find.byKey(const ValueKey('atlas-group-xa-main'));
      final label = find.descendant(of: row, matching: find.text('嘉庚楼群'));
      final count = find.descendant(of: row, matching: find.text('5'));
      expect(
        tester.getCenter(label).dy,
        closeTo(tester.getCenter(count).dy, 1),
      );
      expect(tester.widget<Text>(label).maxLines, 1);
      Future<void> snapshot(String name) async {
        if (Platform.environment['CAPTURE_ATLAS_UI'] != '1') return;
        await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/campus-atlas-review').create(recursive: true);
          await File(
            'build/campus-atlas-review/$name-$dark.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await snapshot('overview-refined');
      final baseline = map().areas.singleWhere(
        (area) => area.hitValue == 'xa-main',
      );
      expect(baseline.color!.a, greaterThan(.06));
      await tester.tap(row);
      await tester.pumpAndSettle();
      final selected = map().areas.singleWhere(
        (area) => area.hitValue == 'xa-main',
      );
      expect(selected.color!.a, greaterThan(baseline.color!.a));
      expect(
        selected.borderStrokeWidth,
        greaterThan(baseline.borderStrokeWidth),
      );
      expect(map().places.any((p) => p.id.startsWith('atlas-group:')), isFalse);
      await snapshot('group-refined');
      final controller = map().controller!;
      controller.move(Campus.xiangan.center, 18.2);
      await tester.pumpAndSettle();
      expect(map().places.any((p) => p.note == '学武楼 A区'), isTrue);
      controller.move(Campus.xiangan.center, 16);
      await tester.pumpAndSettle();
      expect(map().places.any((p) => p.id == 'atlas-group:xa-main'), isTrue);
      expect(map().places.any((p) => p.note == '学武楼 A区'), isFalse);
      controller.move(Campus.xiangan.center, 17.8);
      await tester.pumpAndSettle();
      expect(map().places.any((p) => p.note == '学武楼（1号楼）'), isTrue);
      expect(map().places.any((p) => p.id.startsWith('atlas-group:')), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('all three campus selectors fit their own maintained directory', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const CampusAtlasPage()),
    );
    await tester.pumpAndSettle();
    for (final campus in [Campus.siming, Campus.zhangzhou, Campus.xiangan]) {
      await tester.tap(find.text(campus.label));
      await tester.pumpAndSettle();
      final map = tester.widget<CampusMap>(find.byType(CampusMap));
      expect(map.places, isNotEmpty);
      expect(map.places.every((p) => campusForPoint(p) == campus), isTrue);
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!
          .camera;
      for (final b in teachingBuildings.where(
        (b) => '${b.campus}校区' == campus.label,
      )) {
        for (final point in [
          b.point,
          ...b.regions.map((r) => r.point),
        ].whereType<TeachingPoint>().where((p) => p.usable)) {
          expect(
            camera.visibleBounds.contains(
              LatLng(point.latitude, point.longitude),
            ),
            isTrue,
            reason: b.name,
          );
        }
      }
      expect(tester.takeException(), isNull);
    }
  });
  for (final dark in [false, true]) {
    testWidgets(
      'desktop minimum outer window keeps atlas directory dark=$dark',
      (tester) async {
        tester.view.physicalSize = AppLayout.minimumWindowSize;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
            builder: (_, child) => RepaintBoundary(key: capture, child: child),
            home: Builder(
              builder: (context) => Column(
                children: [
                  const SizedBox(height: AppLayout.titleBarHeight),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(width: AppLayout.sidebarWidthOf(context)),
                        const Expanded(child: CampusAtlasPage()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(CampusAtlasPage)).width,
          lessThan(800),
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('atlas-desktop-directory')))
              .width,
          200,
        );
        expect(
          find.byKey(const ValueKey('atlas-open-directory')),
          findsNothing,
        );
        expect(find.byType(CampusMap), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (Platform.environment['CAPTURE_ATLAS_UI'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(
              'build/campus-atlas-review',
            ).create(recursive: true);
            await File(
              'build/campus-atlas-review/minimum-window-$dark.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('desktop directory shrinks with its window and caps at 280', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [1200.0, 900.0, 1500.0]) {
      tester.view.physicalSize = Size(size, 850);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
          home: const CampusAtlasPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('atlas-desktop-directory')))
            .width,
        closeTo((size * .24).clamp(200.0, 280.0), .01),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'map group and region taps update selection without moving or zooming',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const CampusAtlasPage()),
      );
      await tester.pumpAndSettle();
      CampusMap map() => tester.widget<CampusMap>(find.byType(CampusMap));
      final controller = map().controller!;
      Future<void> select(SavedLocation place) async {
        final center = controller.camera.center, zoom = controller.camera.zoom;
        map().onPlace!(place);
        await tester.pumpAndSettle();
        expect(controller.camera.center, center);
        expect(controller.camera.zoom, zoom);
        expect(map().selectedPlaceId, place.id);
      }

      await select(
        map().places.singleWhere((p) => p.id == 'atlas-group:xa-main'),
      );
      final groupCenter = controller.camera.center;
      final groupZoom = controller.camera.zoom;
      await tester.tap(find.text('详情'));
      await tester.pumpAndSettle();
      expect(find.text('楼群成员'), findsOneWidget);
      expect(find.text('校区建设背景'), findsNothing);
      expect(find.text('沿革与命名'), findsWidgets);
      await tester.tap(find.byTooltip('关闭介绍'));
      await tester.pumpAndSettle();
      expect(controller.camera.center, groupCenter);
      expect(controller.camera.zoom, groupZoom);
      await select(
        map().places.singleWhere((p) => p.id == 'atlas-group:xa-west'),
      );
      final xuewu = teachingBuildings.singleWhere((b) => b.id == 'xa-xuewu');
      final a = xuewu.regions.singleWhere((r) => r.code == 'A').point!;
      controller.move(LatLng(a.latitude, a.longitude), 18.2);
      await tester.pumpAndSettle();
      await select(map().places.singleWhere((p) => p.id == a.id));
      final b = xuewu.regions.singleWhere((r) => r.code == 'B').point!;
      await select(map().places.singleWhere((p) => p.id == b.id));
      expect(find.text('学武楼（1号楼）简介'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'group details and missing individual evidence remain readable with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final building in [
        null,
        teachingBuildings.singleWhere((b) => b.id == 'xa-hemu'),
        teachingBuildings.singleWhere((b) => b.id == 'sm-archives'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 640),
                textScaler: TextScaler.linear(1.5),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => CampusStoryDialog(
                      building: building,
                      group: teachingGroups.singleWhere(
                        (g) => g.id == 'xa-main',
                      ),
                    ),
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        expect(find.byType(CampusStoryDialog), findsOneWidget);
        if (building == null) {
          expect(find.text('楼群成员'), findsOneWidget);
          expect(find.text('营建沿革'), findsNothing);
          expect(find.text('校区建设背景'), findsNothing);
          expect(find.text('沿革与命名'), findsWidgets);
        } else {
          expect(find.text('资料状态'), findsNothing);
          expect(
            find.textContaining('了解'),
            building.id == 'xa-hemu' ? findsOneWidget : findsNothing,
          );
        }
        await tester.drag(
          find.byKey(const ValueKey('atlas-story-scroll')),
          const Offset(0, -1600),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('关闭介绍'));
        await tester.pumpAndSettle();
        expect(find.byType(CampusStoryDialog), findsNothing);
      }
    },
  );
  testWidgets(
    'new restaurant history reaches the map card and offline details',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
          builder: (_, child) => RepaintBoundary(key: capture, child: child),
          home: const CampusAtlasPage(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('思明校区'));
      await tester.pumpAndSettle();
      final restaurant = teachingBuildings.singleWhere(
        (b) => b.id == 'user-596e32d9d6464f54a59abc2775748175',
      );
      final map = tester.widget<CampusMap>(find.byType(CampusMap));
      map.onPlace!(map.places.singleWhere((p) => p.id == restaurant.point!.id));
      await tester.pumpAndSettle();
      expect(find.textContaining('芙蓉餐厅是芙蓉园区1998年'), findsOneWidget);
      expect(find.text('这处建筑的校史与建筑介绍正在补充。'), findsNothing);
      if (Platform.environment['CAPTURE_ATLAS_UI'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/campus-atlas-review/researched-restaurant.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final beforeDetails = map.controller!.camera.center;
      await tester.tap(find.text('详情'));
      await tester.pumpAndSettle();
      expect(find.text('沿革与命名'), findsOneWidget);
      expect(find.textContaining('两楼通过连廊相接'), findsOneWidget);
      expect(find.text('参考资料'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭介绍'));
      await tester.pumpAndSettle();
      expect(
        beforeDetails,
        tester
            .widget<CampusMap>(find.byType(CampusMap))
            .controller!
            .camera
            .center,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'building detail lists multiple source titles without external links',
    (tester) async {
      final building = teachingBuildings.singleWhere(
        (b) => b.id == 'xa-dewang',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => CampusStoryDialog(building: building),
                ),
                child: const Text('打开档案'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开档案'));
      await tester.pumpAndSettle();
      final story = campusBuildingStories[building.id]!;
      await tester.ensureVisible(find.text('参考资料'));
      await tester.tap(find.text('参考资料'));
      await tester.pumpAndSettle();
      final sourcesText = [
        ...tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? ''),
        ...tester
            .widgetList<SelectableText>(find.byType(SelectableText))
            .map((t) => t.data ?? ''),
      ].join('\n');
      for (final url in story.sourceUrls) {
        expect(sourcesText, contains(campusStorySources[url]));
      }
      expect(find.textContaining('https://'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭介绍'));
      await tester.pumpAndSettle();
    },
  );
  test(
    'the directory exports maintained groups, geometry and tool/search entry',
    () {
      expect(
        campusTools.any((t) => t.id == 'campus-map' && t.title == '校园地图'),
        isTrue,
      );
      expect(campusSearchFeatures(null).any((t) => t.title == '校园地图'), isTrue);
      expect(teachingGroups.where((g) => g.vertices.isNotEmpty), isNotEmpty);
      expect(
        teachingBuildings.singleWhere((b) => b.id == 'xa-xuewu').groupId,
        'xa-main',
      );
      for (final b in teachingBuildings.where(
        (b) => ['思明', '翔安', '漳州'].contains(b.campus),
      )) {
        for (final point in [
          b.point,
          ...b.regions.map((r) => r.point),
        ].whereType<TeachingPoint>()) {
          expect(
            kXmuMapBounds.contains(LatLng(point.latitude, point.longitude)),
            isTrue,
          );
        }
      }
    },
  );
  test(
    'histories use stable IDs, traceable public sources and explicit group context',
    () {
      final ids = teachingBuildings.map((b) => b.id).toSet();
      expect(campusBuildingStories.keys.every(ids.contains), isTrue);
      final groups = teachingGroups.map((g) => g.id).toSet();
      expect(campusGroupStories.keys.every(groups.contains), isTrue);
      for (final story in [
        ...campusBuildingStories.values,
        ...campusGroupStories.values,
      ]) {
        for (final url in story.sourceUrls) {
          final uri = Uri.parse(url);
          expect(uri.scheme, 'https');
          expect(
            uri.host.endsWith('.xmu.edu.cn') ||
                uri.host.endsWith('.xujc.com') ||
                uri.host.endsWith('.fujian.gov.cn'),
            isTrue,
          );
          expect(campusStorySources.containsKey(url), isTrue);
        }
        expect(story.text.trim(), isNotEmpty);
        expect(campusStorySources.containsKey(story.url), isTrue);
        expect(story.summary.length, lessThanOrEqualTo(90));
      }
      expect(
        teachingGroups
            .where((g) => !g.id.startsWith('independent-'))
            .every((g) => campusGroupStories.containsKey(g.id)),
        isTrue,
      );
      expect(campusBuildingStories.length, greaterThanOrEqualTo(130));
      expect(
        campusBuildingStories['user-f05a81bf5e444da58a690dcc52383a36']!.sections
            .any((s) => s.text.contains('1979') && s.text.contains('1981')),
        isTrue,
      );
      expect(
        campusBuildingStories['xa-chengwei']!.sections.any(
          (s) => s.text.contains('李氏基金'),
        ),
        isTrue,
      );
      expect(campusBuildingStories.containsKey('xa-hemu'), isFalse);
      expect(
        campusBuildingStories['xa-hemu:C']!.sections.any(
          (s) => s.text.contains('工艺放大'),
        ),
        isTrue,
      );
      expect(
        campusBuildingStories.containsKey(
          'user-228f7725c54f4f0ba688d7715e1a1eae',
        ),
        isFalse,
      );
      expect(
        campusBuildingStories['xa-xuewu']!.sections.any(
          (s) => s.text.contains('2012年11月5日'),
        ),
        isTrue,
      );
      expect(
        campusBuildingStories['xa-dewang']!.sourceUrls.toSet().length,
        greaterThan(1),
      );
      final zhuang = teachingBuildings.singleWhere((b) => b.id == 'sm-zhuang');
      final text = campusStoryFor(building: zhuang)!.text;
      expect(text, contains('1988'));
      expect(text, contains('2011'));
      final shared = teachingBuildings.singleWhere(
        (b) => b.id == 'sm-jiageng1',
      );
      expect(campusStoryFor(building: shared)!.text, contains('保欣丽英楼'));
      final fallback = teachingBuildings.singleWhere((b) => b.id == 'xa-hemu');
      expect(campusStoryFor(building: fallback)!.text, startsWith('所在片区的故事：'));
      // The Xiang'an Chengyi must not receive the Siming building's 1950s history.
      expect(
        campusStoryFor(
          building: teachingBuildings.singleWhere((b) => b.id == 'xa-chengyi'),
        ),
        isNotNull,
      );
      expect(
        campusBuildingStories['xa-chengyi']!.text,
        isNot(contains('1951')),
      );
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'compact directory collection is navigation only and opens building history dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
            builder: (_, child) => RepaintBoundary(key: capture, child: child),
            home: const CampusAtlasPage(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .getSize(find.byKey(const ValueKey('atlas-desktop-directory')))
              .width,
          280,
        );
        await tester.tap(find.text('思明校区'));
        await tester.pumpAndSettle();
        final before = tester
            .widget<CampusMap>(find.byType(CampusMap))
            .controller!
            .camera
            .center;
        final other = find.byKey(const ValueKey('atlas-group-_other'));
        await tester.scrollUntilVisible(
          other,
          220,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('atlas-desktop-directory')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(other);
        await tester.pumpAndSettle();
        final map = tester.widget<CampusMap>(find.byType(CampusMap));
        expect(map.controller!.camera.center, before);
        expect(map.places.any((p) => p.id.contains('_other')), isFalse);
        expect(
          find.byKey(const ValueKey('atlas-building-sm-zhuang')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('atlas-building-sm-jiageng1')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(const ValueKey('atlas-building-sm-zhuang')),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('南强二教学楼建于1988年'), findsOneWidget);
        expect(find.text('校方资料'), findsNothing);
        expect(find.text('详情'), findsOneWidget);
        expect(find.byTooltip('校区全览'), findsNothing);
        expect(
          tester.getCenter(find.text('详情')).dy,
          lessThan(tester.getTopLeft(find.textContaining('南强二教学楼建于1988年')).dy),
        );
        expect(find.text('楼宇位置'), findsNothing);
        if (Platform.environment['CAPTURE_ATLAS_UI'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(
              'build/campus-atlas-review',
            ).create(recursive: true);
            await File(
              'build/campus-atlas-review/history-compact-$dark.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        final cameraBeforeDetails = map.controller!.camera;
        await tester.tap(find.text('详情'));
        await tester.pumpAndSettle();
        expect(find.byType(CampusStoryDialog), findsOneWidget);
        expect(find.text('沿革与命名'), findsOneWidget);
        expect(find.textContaining('2011年校庆'), findsOneWidget);
        expect(find.text('参考资料'), findsOneWidget);
        await tester.tap(find.byTooltip('关闭介绍'));
        await tester.pumpAndSettle();
        expect(map.controller!.camera.center, cameraBeforeDetails.center);
        expect(map.controller!.camera.zoom, cameraBeforeDetails.zoom);
        await tester.tap(find.byTooltip('返回目录'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('atlas-group-_other')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  for (final width in [320.0, 390.0, 1100.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'read-only campus directory and regions at $width dark=$dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 860);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final capture = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                platform: width < 800
                    ? TargetPlatform.android
                    : TargetPlatform.windows,
              ),
              builder: (_, child) =>
                  RepaintBoundary(key: capture, child: child),
              home: const CampusAtlasPage(),
            ),
          );
          await tester.pumpAndSettle();
          final initial = tester.widget<CampusMap>(find.byType(CampusMap));
          expect(initial.onTap, isNull);
          expect(initial.areas, isNotEmpty);
          expect(
            initial.places.any((p) => p.id.startsWith('atlas-group:')),
            isTrue,
          );
          if (width < 800) {
            await tester.tap(
              find.byKey(const ValueKey('atlas-open-directory')),
            );
            await tester.pumpAndSettle();
          }
          await tester.enterText(
            find.byKey(const ValueKey('atlas-search')),
            '学武',
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('atlas-building-xa-xuewu')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('atlas-building-xa-kunluan')),
            findsNothing,
          );
          await tester.tap(
            find.byKey(const ValueKey('atlas-building-xa-xuewu')),
          );
          await tester.pumpAndSettle();
          if (width < 800) {
            expect(find.byKey(const ValueKey('atlas-search')), findsNothing);
            await tester.tap(find.widgetWithText(ChoiceChip, 'A区'));
          } else {
            await tester.tap(
              find.byKey(const ValueKey('atlas-region-xa-xuewu:A')),
            );
          }
          await tester.pumpAndSettle();
          final selected = tester.widget<CampusMap>(find.byType(CampusMap));
          expect(selected.point, isNull);
          expect(selected.selectedPlaceId, isNotNull);
          expect(find.byIcon(Icons.location_on), findsNothing);
          expect(find.textContaining('2014年元旦'), findsOneWidget);
          expect(find.text('分区独立位置'), findsNothing);
          expect(find.text('校方资料'), findsNothing);
          expect(find.text('详情'), findsOneWidget);
          expect(find.text('保存定位'), findsNothing);
          expect(find.text('新增楼宇'), findsNothing);
          expect(tester.takeException(), isNull);
          if (Platform.environment['CAPTURE_ATLAS_UI'] == '1') {
            await tester.runAsync(() async {
              final render =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(
                'build/campus-atlas-review',
              ).create(recursive: true);
              await File(
                'build/campus-atlas-review/atlas-$width-$dark.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          final cameraBeforeDetails = selected.controller!.camera;
          await tester.tap(find.text('详情'));
          await tester.pumpAndSettle();
          expect(find.byType(CampusStoryDialog), findsOneWidget);
          expect(find.text('当前分区'), findsNothing);
          expect(find.text('所在片区背景'), findsNothing);
          expect(find.text('参考资料'), findsOneWidget);
          expect(find.textContaining('http'), findsNothing);
          expect(tester.takeException(), isNull);
          if (Platform.environment['CAPTURE_ATLAS_UI'] == '1') {
            await tester.runAsync(() async {
              final image =
                  await (capture.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                'build/campus-atlas-review/details-$width-$dark.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.tap(find.byTooltip('关闭介绍'));
          await tester.pumpAndSettle();
          expect(
            selected.controller!.camera.center,
            cameraBeforeDetails.center,
          );
          expect(selected.controller!.camera.zoom, cameraBeforeDetails.zoom);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
