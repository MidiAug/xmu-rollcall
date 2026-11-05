import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_glass_surface.dart';
import 'package:xmu_rollcall/app/app_service_tile.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

class _ShadowTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _ShadowTestBinding();

  testWidgets('Windows service tile keeps hit area and keyboard activation', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              child: AppServiceTile(
                title: '学年校历',
                description: '学期安排与教学周',
                icon: Icons.calendar_today,
                onPressed: () => calls++,
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.byType(RawImage).evaluate().isNotEmpty) break;
    }
    expect(find.byType(RawImage), findsOneWidget);
    final before = tester.getRect(find.byType(AppServiceTile));
    await tester.tapAt(before.centerLeft - const Offset(5, 0));
    expect(calls, 0, reason: 'the shadow must not enlarge the hit area');
    await tester.tap(find.text('学年校历'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.getRect(find.byType(AppServiceTile)), before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  for (final dark in [false, true]) {
    for (final dpr in [1.0, 1.25, 2.0]) {
      testWidgets(
        'cached shadows retain pixels and layout dark=$dark dpr=$dpr',
        (tester) async {
          tester.view.devicePixelRatio = dpr;
          tester.view.physicalSize = Size(1200 * dpr, 600 * dpr);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final boundaryKey = GlobalKey();
          final surfaceKey = GlobalKey();

          Future<Uint8List> render({
            required bool cached,
            required Size size,
            double opacity = 1,
          }) async {
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                home: Scaffold(
                  body: Center(
                    child: RepaintBoundary(
                      key: boundaryKey,
                      child: ColoredBox(
                        color: dark
                            ? const Color(0xff232831)
                            : const Color(0xfff3f5f8),
                        child: Padding(
                          padding: const EdgeInsets.all(50),
                          child: SizedBox.fromSize(
                            size: size,
                            child: AppGlassSurface(
                              key: surfaceKey,
                              blur: 0,
                              opacity: opacity,
                              cacheShadows: cached,
                              borderRadius: BorderRadius.circular(22),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            // toImage is an engine boundary. Let it complete outside fake time,
            // then pump the real Image stream notification into the widget tree.
            for (var i = 0; i < 30; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 10)),
              );
              await tester.pump();
              if (find.byType(RawImage).evaluate().isNotEmpty) break;
              if (!cached || size.height < 120) break;
            }
            expect(tester.getSize(find.byKey(surfaceKey)), size);
            expect(tester.takeException(), isNull);
            if (cached && size.height >= 120) {
              expect(find.byType(RawImage), findsOneWidget);
            }
            return (await tester.runAsync(() async {
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: dpr);
              try {
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
                return Uint8List.fromList(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            }))!;
          }

          for (final size in [
            const Size(300.4, 130),
            const Size(520, 180),
            const Size(300, 88),
          ]) {
            for (final opacity in [1.0, .78]) {
              final vector = await render(
                cached: false,
                size: size,
                opacity: opacity,
              );
              final cached = await render(
                cached: true,
                size: size,
                opacity: opacity,
              );
              expect(cached.length, vector.length);
              var maximum = 0, total = 0;
              for (var i = 0; i < cached.length; i++) {
                final delta = (cached[i] - vector[i]).abs();
                if (delta > maximum) maximum = delta;
                total += delta;
              }
              expect(
                maximum,
                lessThanOrEqualTo(3),
                reason: 'size=$size opacity=$opacity',
              );
              expect(
                total / cached.length,
                lessThan(.15),
                reason: 'size=$size opacity=$opacity',
              );
              if (size.height < 120) {
                expect(find.byType(Image), findsNothing);
                expect(
                  maximum,
                  0,
                  reason: 'small surfaces use the original vector painter',
                );
              }
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        },
      );
    }
  }
}
