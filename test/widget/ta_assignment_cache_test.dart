import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_grading_page.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_providers.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_repository.dart';
import '../fixtures/ta_http_fixture.dart';

void main() {
  testWidgets(
    'revisit shows cache immediately and failed refresh keeps course content',
    (tester) async {
      final f = TaHttpFixture();
      final base = await f.repository();
      var now = DateTime(2026, 11, 4, 9);
      final repo = TaGradingRepository(base.http, now: () => now);
      addTearDown(base.dispose);
      addTearDown(repo.dispose);
      final container = ProviderContainer(
        overrides: [
          taRepositoryProvider.overrideWith((ref) async => repo),
          currentTeachingCoursesProvider.overrideWith(
            (ref) async => const [CatalogCourse(id: '91', title: '缓存课程')],
          ),
        ],
      );
      addTearDown(container.dispose);
      Future<void> mount() => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
            home: const Scaffold(body: TaGradingPage()),
          ),
        ),
      );
      await mount();
      await tester.pumpAndSettle();
      expect(f.requests, hasLength(1));
      final old = repo.cachedAssignments(91);
      await tester.pumpWidget(const SizedBox());
      await mount();
      await tester.pump();
      expect(find.text(TaHttpFixture.title), findsOneWidget);
      expect(f.requests, hasLength(1));
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 5));
      final response = Completer<ResponseBody>();
      f.intercept = (_) => response.future;
      await tester.tap(find.byTooltip('更新作业'));
      await tester.pump();
      expect(find.text(TaHttpFixture.title), findsOneWidget);
      response.complete(TaHttpFixture.response({'pages': -1}));
      await tester.pumpAndSettle();
      expect(find.text(TaHttpFixture.title), findsOneWidget);
      expect(find.text('更新失败，保留上次作业列表'), findsOneWidget);
      expect(repo.cachedAssignments(91), same(old));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
