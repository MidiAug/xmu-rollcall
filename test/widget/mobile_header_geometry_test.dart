import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/mobile_campus_header.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets(
          'campus headers share artwork geometry at $platform / $width / $scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light().copyWith(platform: platform),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const Scaffold(
                  body: Column(
                    children: [
                      MobileCampusHeader(child: Text('签到')),
                      MobileCampusHeader(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('我的账号'),
                            SizedBox(height: 12),
                            Text('账号管理'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final headers = find.byKey(const ValueKey('mobile-campus-header'));
            final artwork = find.byKey(const ValueKey('mobile-campus-artwork'));
            expect(tester.getSize(headers.first), tester.getSize(headers.last));
            expect(tester.getSize(artwork.first), tester.getSize(artwork.last));
            expect(
              tester.getTopLeft(artwork.first) -
                  tester.getTopLeft(headers.first),
              tester.getTopLeft(artwork.last) - tester.getTopLeft(headers.last),
            );
            final lift =
                tester.getTopLeft(artwork.first).dy -
                tester.getTopLeft(headers.first).dy;
            expect(lift, platform == TargetPlatform.android ? -76 : 0);
            if (platform == TargetPlatform.android) {
              expect(
                tester.getTopLeft(artwork.first).dx -
                    tester.getTopLeft(headers.first).dx,
                18,
              );
              expect(
                tester.getTopLeft(find.text('签到')).dy -
                    tester.getTopLeft(headers.first).dy,
                closeTo(16, .01),
              );
              expect(
                tester.getTopLeft(find.text('我的账号')).dy -
                    tester.getTopLeft(headers.last).dy,
                closeTo(16, .01),
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
