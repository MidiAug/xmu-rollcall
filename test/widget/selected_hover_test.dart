import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/location/campus_map.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

Future<Color> sample(WidgetTester tester, Offset point) async {
  final result = await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('desktop-ui-capture')),
    );
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final at = (point.dy.floor() * image.width + point.dx.floor()) * 4;
    final bytes = data!.buffer.asUint8List();
    final color = Color.fromARGB(
      bytes[at + 3],
      bytes[at],
      bytes[at + 1],
      bytes[at + 2],
    );
    image.dispose();
    return color;
  });
  return result!;
}

void main() {
  initializeDesktopUiCapture();
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => (await Directory(
            'build/map-test-cache',
          ).create(recursive: true)).absolute.path,
        );
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  for (final dark in [false, true]) {
    for (final map in [true, false]) {
      testWidgets(
        'selected ${map ? "map label" : "shared surface"} retains contrast through hover press and focus dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(640, 480);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final theme = desktopCaptureTheme(
            (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
          );
          final palette = dark
              ? AppPalette.darkPalette
              : AppPalette.lightPalette;
          final place = SavedLocation(
            id: 'selected-test',
            note: '实验动物中心',
            latitude: 24.606,
            longitude: 118.312,
            createdAt: DateTime(2026),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder: (context, child) => RepaintBoundary(
                key: const ValueKey('desktop-ui-capture'),
                child: child!,
              ),
              home: Scaffold(
                body: map
                    ? CampusMap(
                        center: const LatLng(24.606, 118.312),
                        zoom: 18,
                        places: [place],
                        selectedPlaceId: place.id,
                        showPlaceLabels: true,
                        onPlace: (_) {},
                      )
                    : Center(
                        child: AppHoverSurface(
                          backgroundColor: palette.primary,
                          onTap: () {},
                          child: SizedBox(
                            width: 220,
                            height: 60,
                            child: Center(
                              child: Text(
                                place.note,
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final label = find.text(place.note);
          final target = map
              ? find.byKey(ValueKey('map-place-${place.note}'))
              : find.byType(AppHoverSurface);
          final rect = tester.getRect(target);
          final point = Offset(rect.center.dx, rect.top + 5);
          final idle = await sample(tester, point);
          expect(idle, palette.primary);
          Future<void> check(String state) async {
            final actual = await sample(tester, point);
            final foreground = theme.colorScheme.onPrimary;
            final a = actual.computeLuminance(),
                b = foreground.computeLuminance();
            expect(
              ((a > b ? a : b) + .05) / ((a > b ? b : a) + .05),
              greaterThanOrEqualTo(4.5),
              reason: state,
            );
            if (state == 'focus') {
              expect(
                actual,
                isNot(idle),
                reason: 'Keyboard focus must remain visible',
              );
            } else {
              expect(
                (actual.computeLuminance() - idle.computeLuminance()).abs(),
                lessThan(.12),
                reason: state,
              );
            }
            await captureDesktopUi(
              tester,
              'selected-${map ? "map" : "surface"}-$state-$dark',
            );
          }

          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(rect.center);
          await tester.pump(const Duration(milliseconds: 50));
          await check('hover-middle');
          await tester.pumpAndSettle();
          await check('hover');
          await mouse.down(rect.center);
          await tester.pumpAndSettle();
          await check('pressed');
          await mouse.up();
          await mouse.moveTo(Offset.zero);
          await tester.pumpAndSettle();
          expect(
            await sample(tester, point),
            idle,
            reason: 'Leaving the pointer restores the selected surface',
          );
          Focus.of(tester.element(label)).requestFocus();
          await tester.pumpAndSettle();
          await check('focus');
          await mouse.removePointer();
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
