import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/theme/app_typography.dart';

import '../fixtures/preview_fonts.dart';

void main() {
  setUpAll(loadDesktopPreviewFonts);

  testWidgets(
    'layout fixtures resolve platform text families to readable fonts',
    (tester) async {
      double width(String text) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: AppTypography.body.copyWith(fontSize: 20),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final result = painter.width;
        painter.dispose();
        return result;
      }

      // FlutterTest uses equal-width boxes for these letters. Checking actual
      // metrics catches an unloaded/misnamed font even if FontLoader completes.
      expect(width('WWWW'), greaterThan(width('iiii') * 2));
      expect(width('课程表'), closeTo(60, 0.5));
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.iOS,
    }),
  );
}
