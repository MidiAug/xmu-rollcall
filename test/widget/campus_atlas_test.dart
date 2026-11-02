import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/campus/campus_tools_page.dart';
import 'package:xmu_rollcall/features/campus/campus_search_index.dart';
import 'package:xmu_rollcall/features/location/campus_atlas_page.dart';
import 'package:xmu_rollcall/features/location/campus_map.dart';
import 'package:xmu_rollcall/features/location/campus_map_config.dart';
import 'package:xmu_rollcall/features/location/teaching_catalog.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/place_matching.dart';
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
          expect(selected.point!.latitude, 24.6050038);
          expect(selected.point!.longitude, 118.3137578);
          expect(find.text('分区独立位置'), findsOneWidget);
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
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
