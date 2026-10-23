import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

void main() {
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
