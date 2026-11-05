import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_grading_page.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_models.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_providers.dart';
import 'package:xmu_rollcall/features/ta_grading/ta_repository.dart';
import '../fixtures/ta_http_fixture.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

Finder scoreField(int id) => find.descendant(
  of: find.byKey(ValueKey('ta-score-$id')),
  matching: find.byType(TextField),
);

Future<void> open(
  WidgetTester tester,
  TaGradingRepository repo, {
  bool dark = false,
  bool settleDetail = true,
  bool openDetail = true,
}) async {
  tester.view.physicalSize = const Size(1100, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(AppToast.dismiss);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taRepositoryProvider.overrideWith((ref) async => repo),
        currentTeachingCoursesProvider.overrideWith(
          (ref) async => const [CatalogCourse(id: '91', title: '示例助教课程')],
        ),
      ],
      child: RepaintBoundary(
        key: const ValueKey('desktop-ui-capture'),
        child: MaterialApp(
          theme: desktopCaptureTheme(
            (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
          ),
          home: const Scaffold(body: TaGradingPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (!openDetail) return;
  await tester.tap(find.text(TaHttpFixture.title));
  if (settleDetail) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  initializeDesktopUiCapture();
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  for (final dark in [false, true]) {
    testWidgets(
      'Enter saves an existing score once and keeps focus dark=$dark',
      (tester) async {
        final f = TaHttpFixture()..scores[1] = 72;
        final repo = await f.repository();
        addTearDown(repo.dispose);
        await open(tester, repo, dark: dark);
        expect(tester.widget<TextField>(scoreField(1)).controller!.text, '72');
        expect(find.text('待核对'), findsNothing);
        expect(find.textContaining('已批改 1'), findsOneWidget);
        final gate = Completer<void>();
        f.intercept = (r) async {
          if (r.method == 'PUT') await gate.future;
          return null;
        };
        await tester.enterText(scoreField(1), '86.5');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.widget<TextField>(scoreField(1)).readOnly, isTrue);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        gate.complete();
        await tester.pumpAndSettle();
        expect(f.requests.where((r) => r.method == 'PUT'), hasLength(1));
        expect(f.scores[1], 86.5);
        expect(find.text('示例学生1的成绩已保存'), findsOneWidget);
        expect(find.text('确认提交成绩'), findsNothing);
        expect(
          tester.widget<TextField>(scoreField(1)).focusNode!.hasFocus,
          isTrue,
        );
        expect(
          (await repo.restoreStudents(91, 81))!.students.first.score,
          86.5,
        );
        await captureDesktopUi(tester, 'ta-inline-saved-$dark');
        AppToast.dismiss();
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(f.requests.where((r) => r.method == 'PUT'), hasLength(1));
        expect(find.text('成绩未变化'), findsOneWidget);
        AppToast.dismiss();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('invalid input never writes, zero is a valid score', (
    tester,
  ) async {
    final f = TaHttpFixture();
    final repo = await f.repository();
    addTearDown(repo.dispose);
    await open(tester, repo);
    for (final value in ['', '-1', '101', 'NaN', '1e2']) {
      await tester.enterText(scoreField(1), value);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('分数应为 0 至 100，空白不提交'), findsOneWidget);
      expect(f.requests.where((r) => r.method == 'PUT'), isEmpty);
    }
    await tester.enterText(scoreField(1), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(f.scores[1], 0);
    expect(tester.widget<TextField>(scoreField(3)).readOnly, isTrue);
    AppToast.dismiss();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'failed PUT retains draft, cache and server value without retry',
    (tester) async {
      final f = TaHttpFixture()..scores[1] = 20;
      final repo = await f.repository();
      addTearDown(repo.dispose);
      await open(tester, repo);
      f.intercept = (r) async =>
          r.method == 'PUT' ? TaHttpFixture.response({}, 503) : null;
      await tester.enterText(scoreField(1), '91');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(f.requests.where((r) => r.method == 'PUT'), hasLength(1));
      expect(f.scores[1], 20);
      expect(tester.widget<TextField>(scoreField(1)).controller!.text, '91');
      expect((await repo.restoreStudents(91, 81))!.students.first.score, 20);
      expect(find.text('成绩同步失败，输入已保留，请稍后刷新'), findsOneWidget);
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'cached roster appears before detail returns, then refreshes automatically',
    (tester) async {
      final f = TaHttpFixture()..scores[1] = 39;
      final repo = await f.repository();
      addTearDown(repo.dispose);
      await repo.cacheStudents(91, 81, const [
        TaStudent(
          id: 1,
          number: '0001',
          name: '缓存学生',
          submitted: true,
          score: 54,
          scoreChecked: true,
        ),
      ]);
      final gate = Completer<void>();
      f.intercept = (r) async {
        if (r.uri.path == '/api/activities/81') await gate.future;
        return null;
      };
      await open(tester, repo, settleDetail: false);
      expect(find.text('缓存学生'), findsOneWidget);
      expect(tester.widget<TextField>(scoreField(1)).controller!.text, '54');
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('缓存学生'), findsNothing);
      expect(find.text('示例学生1'), findsOneWidget);
      expect(tester.widget<TextField>(scoreField(1)).controller!.text, '39');
      expect(f.requests.where((r) => r.method == 'PUT'), isEmpty);
    },
  );
  testWidgets('a late refresh cannot overwrite a newly saved grade or draft', (
    tester,
  ) async {
    final f = TaHttpFixture()..scores[1] = 39;
    final repo = await f.repository();
    addTearDown(repo.dispose);
    await repo.cacheStudents(91, 81, const [
      TaStudent(
        id: 1,
        number: '0001',
        name: '缓存学生',
        submitted: true,
        score: 54,
        scoreChecked: true,
      ),
    ]);
    final gate = Completer<void>();
    var first = true;
    f.intercept = (r) async {
      if (r.uri.path.endsWith('/submitter/1/score-records') && first) {
        first = false;
        await gate.future;
        return TaHttpFixture.response({
          'pages': 1,
          'records': [
            {'id': 1, 'created_at': '2026-01-01T00:00:00Z', 'final_score': 39},
          ],
        });
      }
      return null;
    };
    await open(tester, repo, settleDetail: false);
    await tester.enterText(scoreField(1), '91');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(f.scores[1], 91);
    expect(tester.widget<TextField>(scoreField(1)).controller!.text, '91');
    await tester.enterText(scoreField(1), '92');
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(scoreField(1)).controller!.text, '92');
    expect((await repo.restoreStudents(91, 81))!.students.first.score, 91);
    expect(f.requests.where((r) => r.method == 'PUT'), hasLength(1));
    AppToast.dismiss();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  for (final dark in [false, true]) {
    testWidgets(
      'five compact assignment destinations fit the desktop view dark=$dark',
      (tester) async {
        final f = TaHttpFixture();
        f.intercept = (r) async => r.uri.path.endsWith('/homework-activities')
            ? TaHttpFixture.response({
                'pages': 1,
                'homework_activities': [
                  for (var i = 1; i <= 5; i++)
                    {
                      ...f.assignment,
                      'id': 80 + i,
                      'title': '第$i讲作业',
                      'expected_submit_count': 111,
                      'submitted_count': 40 + i,
                      'scored_count': i - 1,
                    },
                ],
              })
            : null;
        final repo = await f.repository();
        addTearDown(repo.dispose);
        await open(tester, repo, dark: dark, openDetail: false);
        tester.view.physicalSize = const Size(1100, 771);
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('第5讲作业')).bottom, lessThan(771));
        final rect = tester.getRect(find.text('第1讲作业'));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(rect.center);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getRect(find.text('第1讲作业')), rect);
        await captureDesktopUi(tester, 'ta-five-assignments-hover-$dark');
        await mouse.removePointer();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
