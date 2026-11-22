import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/logging/app_log.dart';
import 'package:xmu_rollcall/core/logging/log_record.dart';
import 'package:xmu_rollcall/core/logging/memory_log_index.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/settings/recent_logs_page.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(loadDesktopPreviewFonts);
  tearDown(() => AppLog.resetForTest());
  for (final width in [320.0, 960.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'lazy log group searches and follows live events $width dark=$dark',
        (tester) async {
          final index = MemoryLogIndex();
          for (var i = 0; i < 400; i++) {
            index.add(
              LogRecord(
                ts: DateTime(2026, 11, 22, 10, 0, i),
                level: 'I',
                event: 'diagnostic.fixture.$i',
                opId: 'operation-$i',
                fields: {'rollcallId': i, 'ok': true, 'status': 200},
              ),
            );
          }
          await AppLog.resetForTest(index: index);
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            ProviderScope(
              child: RepaintBoundary(
                key: const ValueKey('desktop-ui-capture'),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: dark ? AppTheme.dark() : AppTheme.light(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(width == 320 ? 2 : 1),
                    ),
                    child: child!,
                  ),
                  home: const RecentLogsPage(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('diagnostic.fixture.399'), findsOneWidget);
          expect(find.text('diagnostic.fixture.0'), findsNothing);
          expect(find.byType(SelectableText).evaluate().length, lessThan(30));
          await captureDesktopUi(tester, 'logs-r22-${width.toInt()}-$dark');
          await tester.enterText(find.byType(TextField), '7');
          await tester.pumpAndSettle();
          expect(find.text('diagnostic.fixture.7'), findsOneWidget);
          expect(find.text('diagnostic.fixture.399'), findsNothing);
          index.add(
            LogRecord(
              ts: DateTime(2026, 11, 22, 12),
              level: 'I',
              event: 'new scoped event',
              fields: {'rollcallId': 7},
            ),
          );
          AppLog.revision.value++;
          await tester.pumpAndSettle();
          expect(find.text('new scoped event'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
