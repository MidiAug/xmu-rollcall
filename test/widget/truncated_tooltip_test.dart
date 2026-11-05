import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('shared tooltip hover waits 500ms dark=$dark', (tester) async {
      const fullName = 'A very long course name';
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                AppIconButton(
                  tooltip: '更新',
                  icon: const Icon(Icons.refresh),
                  onPressed: () {},
                ),
                const SizedBox(width: 80, child: AppTruncatedText(fullName)),
              ],
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 500));
      addTearDown(mouse.removePointer);
      for (final label in ['更新', fullName]) {
        final anchor = find.byTooltip(label);
        final sourceCount = label == fullName ? 1 : 0;
        await mouse.moveTo(tester.getCenter(anchor));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 499));
        expect(find.text(label), findsNWidgets(sourceCount));
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        expect(find.text(label), findsNWidgets(sourceCount + 1));
        await mouse.moveTo(const Offset(700, 500));
        await tester.pumpAndSettle();
        expect(find.text(label), findsNWidgets(sourceCount));
        // A brief pass must cancel its pending display, even after waiting away.
        await mouse.moveTo(tester.getCenter(anchor));
        await tester.pump(const Duration(milliseconds: 200));
        await mouse.moveTo(const Offset(700, 500));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(label), findsNWidgets(sourceCount));
      }
      await tester.longPress(find.byTooltip('更新'));
      await tester.pump();
      expect(find.text('更新'), findsOneWidget);
    });
  }

  testWidgets('only ellipsized labels have full-text tooltips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Column(
            children: [
              SizedBox(width: 200, child: AppTruncatedText('7天内')),
              SizedBox(
                width: 80,
                child: AppTruncatedText('A very long course name'),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byTooltip('7天内'), findsNothing);
    expect(find.byTooltip('A very long course name'), findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(find.text('7天内')).didExceedMaxLines,
      isFalse,
    );
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('A very long course name'))
          .didExceedMaxLines,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
