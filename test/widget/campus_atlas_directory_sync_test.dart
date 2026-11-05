import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/location/campus_atlas_page.dart';
import 'package:xmu_rollcall/features/location/campus_map.dart';
import 'package:xmu_rollcall/features/location/campus_places.dart';
import 'package:xmu_rollcall/features/location/teaching_catalog.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
    final cache = await Directory(
      'build/campus-atlas-cache',
    ).create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.absolute.path,
        );
  });
  for (final large in [false, true]) {
    testWidgets(
      'map picks reveal buildings within the same collection and repeat picks large=$large',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: desktopCaptureTheme(
              (large ? AppTheme.dark() : AppTheme.light()).copyWith(
                platform: TargetPlatform.windows,
              ),
            ),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(large ? 1.4 : 1)),
                child: child!,
              ),
            ),
            home: const CampusAtlasPage(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('atlas-group-_other')));
        await tester.pumpAndSettle();
        CampusMap map() => tester.widget<CampusMap>(find.byType(CampusMap));
        map().controller!.move(Campus.xiangan.center, 17.4);
        await tester.pumpAndSettle();
        final geographicGroups = teachingGroups
            .where((g) => g.campus == '翔安' && !g.id.startsWith('independent-'))
            .map((g) => g.id)
            .toSet();
        final buildings = teachingBuildings
            .where(
              (b) =>
                  b.campus == '翔安' &&
                  !geographicGroups.contains(b.groupId) &&
                  b.point?.usable == true,
            )
            .toList();
        expect(buildings.length, greaterThan(10));
        final first = buildings.first, last = buildings.last;
        final camera = map().controller!.camera;
        final list = find.byKey(const ValueKey('atlas-building-list'));
        ScrollController scrolling() =>
            tester.widget<SingleChildScrollView>(list).controller!;
        Finder row(TeachingBuilding b) =>
            find.byKey(ValueKey('atlas-building-${b.id}'));
        void visible(TeachingBuilding b) {
          final viewport = tester.getRect(list),
              target = tester.getRect(row(b));
          expect(target.top, greaterThanOrEqualTo(viewport.top));
          expect(target.bottom, lessThanOrEqualTo(viewport.bottom));
          expect(row(b).hitTestable(), findsOneWidget);
        }

        Future<void> pick(TeachingBuilding b) async {
          final current = map();
          current.onPlace!(
            current.places.singleWhere((p) => p.id == b.point!.id),
          );
          await tester.pumpAndSettle();
          visible(b);
          expect(map().controller!.camera.center, camera.center);
          expect(map().controller!.camera.zoom, camera.zoom);
        }

        await pick(last);
        expect(scrolling().offset, greaterThan(0));
        await captureDesktopUi(tester, 'atlas-same-collection-last-$large');
        scrolling().jumpTo(0);
        await tester.pumpAndSettle();
        expect(
          scrolling().offset,
          0,
          reason:
              'Manual scrolling is not pulled back to the current selection',
        );
        expect(row(last).hitTestable(), findsNothing);
        await pick(last);
        await pick(first);
        await captureDesktopUi(tester, 'atlas-same-collection-first-$large');
        final search = find.byKey(const ValueKey('atlas-search'));
        await tester.enterText(search, last.name);
        await tester.pumpAndSettle();
        await pick(last);
        expect(
          tester.widget<TextField>(search).controller!.text,
          last.name,
          reason: 'A search matching the chosen building stays intact',
        );
        await pick(first);
        expect(
          tester.widget<TextField>(search).controller!.text,
          isEmpty,
          reason: 'A map pick clears only a search that hides its target',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
