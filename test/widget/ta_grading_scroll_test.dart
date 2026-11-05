import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_checkbox.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_grading_page.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_providers.dart';
import '../fixtures/ta_http_fixture.dart';

void main() {
  for (final (count, scale) in [(111, 1.0), (1000, 1.0), (111, 2.0)]) {
    testWidgets(
      'roster scrolling stays lazy and preserves selection with $count students scale=$scale',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = TaHttpFixture(
          studentCount: count,
          submittedCount: count,
        )..zip = null;
        final repo = await fixture.repository();
        // Decode fixture JSON synchronously; fake time cannot drive Dio's
        // background isolate for large responses. Loading is outside timing.
        repo.http.dio.transformer = SyncTransformer();
        addTearDown(repo.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              taRepositoryProvider.overrideWith((ref) async => repo),
              currentTeachingCoursesProvider.overrideWith(
                (ref) async => const [CatalogCourse(id: '91', title: '滚动测试课程')],
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              theme: AppTheme.light().copyWith(
                platform: TargetPlatform.windows,
              ),
              home: const Scaffold(body: TaGradingPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(TaHttpFixture.title));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('ta-select-all')));
        await tester.pumpAndSettle();
        final list = find.byKey(const ValueKey('ta-assignment-scroll'));
        final position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        final requestsBefore = fixture.requests.length;
        final samples = <int>[];
        final benchmark = Platform.environment['BENCH_TA_SCROLL'] == '1';
        for (var run = 0; run < (benchmark ? 4 : 1); run++) {
          position.jumpTo(0);
          await tester.pumpAndSettle();
          final watch = Stopwatch()..start();
          for (var frame = 1; frame <= 60; frame++) {
            final step = frame <= 30 ? frame : 60 - frame;
            position.jumpTo((step * 96.0).clamp(0, position.maxScrollExtent));
            await tester.pump(const Duration(milliseconds: 16));
          }
          watch.stop();
          if (run > 0) samples.add(watch.elapsedMicroseconds);
        }
        // Diagnostic CPU wall time in the widget-test engine, not native FPS.
        if (benchmark) {
          samples.sort();
          debugPrint(
            'TA_SCROLL_BENCH ${jsonEncode({'students': count, 'frames': 60, 'samples_us': samples, 'median_us': samples[1]})}',
          );
        }
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(find.text('示例学生$count'), findsOneWidget);
        expect(find.byType(AppCheckbox).evaluate().length, lessThan(40));
        expect(fixture.requests.length, requestsBefore);
        expect(find.text('已选 $count 人'), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('ta-select-$count')));
        await tester.pumpAndSettle();
        expect(find.text('已选 ${count - 1} 人'), findsOneWidget);
        expect(
          tester
              .widget<AppCheckbox>(find.byKey(const ValueKey('ta-select-all')))
              .value,
          isNull,
        );
        expect(find.byKey(ValueKey('ta-score-$count')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
