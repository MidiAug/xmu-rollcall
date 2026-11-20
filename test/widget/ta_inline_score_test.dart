import 'dart:async';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/cache/course_catalog_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
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
  String? csv,
  List<CatalogCourse>? courses,
}) async {
  tester.view.physicalSize = const Size(1100, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(AppToast.dismiss);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (csv != null)
          taCsvReaderProvider.overrideWith(
            (ref) =>
                () async => csv,
          ),
        taRepositoryProvider.overrideWith((ref) async => repo),
        currentTeachingCoursesProvider.overrideWith(
          (ref) async =>
              courses ?? const [CatalogCourse(id: '91', title: '示例助教课程')],
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
  testWidgets(
    'cold entry publishes the complete 111-person grade roster at once',
    (tester) async {
      final f = TaHttpFixture(studentCount: 111, submittedCount: 111);
      for (var id = 1; id <= 111; id++) {
        f.scores[id] = id == 111 ? 0 : 86.5;
      }
      final gate = Completer<void>();
      f.intercept = (r) async {
        if (r.uri.path.endsWith('/homework-scores')) await gate.future;
        return null;
      };
      final repo = await f.repository();
      addTearDown(repo.dispose);
      await open(tester, repo, settleDetail: false);
      expect(scoreField(1), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(scoreField(1)).controller!.text, '86.5');
      final cached = await repo.restoreStudents(91, 81);
      expect(cached!.students, hasLength(111));
      expect(cached.students.last.score, 0);
      expect(
        f.requests.where((r) => r.uri.path.endsWith('/homework-scores')),
        hasLength(1),
      );
      expect(
        f.requests.where((r) => r.uri.path.endsWith('/score-records')),
        isEmpty,
      );
      await captureDesktopUi(tester, 'ta-bulk-grades-111');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
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
    expect(scoreField(3), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('ta-score-3')),
        matching: find.text('未提交'),
      ),
      findsOneWidget,
    );
    AppToast.dismiss();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'unsupported grading is a readable result rather than an editor',
    (tester) async {
      final f = TaHttpFixture()..group = true;
      f.scores[1] = 0;
      final repo = await f.repository();
      addTearDown(repo.dispose);
      await open(tester, repo);
      expect(scoreField(1), findsNothing);
      expect(scoreField(2), findsNothing);
      final cell = find.byKey(const ValueKey('ta-score-1'));
      expect(
        find.descendant(of: cell, matching: find.text('0')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cell, matching: find.text('本作业只读')),
        findsOneWidget,
      );
      final semantics = tester.ensureSemantics();
      final node = tester.getSemantics(cell);
      expect(node.hint, '本作业只读');
      expect(node.value, '0');
      expect(node.hint, isNot(contains('回车')));
      semantics.dispose();
      expect(f.requests.where((r) => r.method == 'PUT'), isEmpty);
      await captureDesktopUi(tester, 'ta-readonly-grades');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
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
      expect(scoreField(1), findsNothing);
      expect(find.text('54'), findsOneWidget);
      expect(find.text('正在核对评分权限'), findsOneWidget);
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
      if (r.uri.path.endsWith('/homework-scores') && first) {
        first = false;
        await gate.future;
        return TaHttpFixture.response({
          'homework_scores': [
            {'activity_id': 81, 'student_id': 1, 'final_score': '39'},
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
  for (final dark in [false, true]) {
    testWidgets('attachments and paginated score history dark=$dark', (
      tester,
    ) async {
      final f = TaHttpFixture();
      f.intercept = (r) async => r.uri.path.endsWith('/student-submissions')
          ? TaHttpFixture.response({
              'submissions': [
                {
                  'created_by': {'id': 1},
                  'attachments_size': 1178,
                },
                {
                  'created_by': {'id': 2},
                },
              ],
            })
          : null;
      final repo = await f.repository();
      addTearDown(repo.dispose);
      await open(tester, repo, dark: dark);
      expect(find.text('附件大小'), findsOneWidget);
      expect(find.text('1.15 KB'), findsOneWidget);
      expect(find.byTooltip('有附件'), findsOneWidget);
      expect(find.text('无附件'), findsNWidgets(2));
      await captureDesktopUi(tester, 'ta-attachment-columns-$dark');
      f.intercept = (r) async => r.uri.path.endsWith('/score-records')
          ? TaHttpFixture.response({
              'pages': 2,
              'records': r.uri.queryParameters['page'] == '1'
                  ? [
                      {
                        'id': 2,
                        'created_at': '2026-11-02T10:00:00Z',
                        'old_final_score': 80,
                        'final_score': 90,
                        'operator_name': '示例助教',
                      },
                    ]
                  : [
                      {
                        'id': 1,
                        'created_at': '2026-11-01T10:00:00Z',
                        'old_final_score': null,
                        'final_score': 80,
                        'operator_name': '示例教师',
                      },
                    ],
            })
          : null;
      expect(find.text('操作'), findsOneWidget);
      final historyAction = find.byKey(const ValueKey('ta-score-history-1'));
      expect(
        find.descendant(
          of: historyAction,
          matching: find.byIcon(AppIcons.history),
        ),
        findsOneWidget,
      );
      expect(AppIcons.history, isNot(AppIcons.refresh));
      expect(
        tester.getRect(find.text('操作')).left,
        closeTo(tester.getRect(historyAction).left, 1),
      );
      await tester.tap(find.byKey(const ValueKey('ta-score-history-1')));
      await tester.pumpAndSettle();
      expect(find.text('评分记录'), findsOneWidget);
      expect(find.text('示例助教'), findsOneWidget);
      expect(find.text('示例教师'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(
        f.requests.where((r) => r.uri.queryParameters['page'] == '2'),
        hasLength(1),
      );
      expect(f.requests.where((r) => r.method == 'PUT'), isEmpty);
      await captureDesktopUi(tester, 'ta-score-history-$dark');
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('评分记录'), findsNothing);
    });
  }
  testWidgets(
    'history failure retries and an in-flight read cancels on close',
    (tester) async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      addTearDown(repo.dispose);
      await open(tester, repo);
      f.intercept = (r) async => r.uri.path.endsWith('/score-records')
          ? TaHttpFixture.response({}, 403)
          : null;
      await tester.tap(find.byKey(const ValueKey('ta-score-history-1')));
      await tester.pumpAndSettle();
      expect(find.text('评分记录加载失败'), findsOneWidget);
      f.intercept = null;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('暂无评分记录'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      f.intercept = (r) async {
        if (r.uri.path.endsWith('/score-records')) await gate.future;
        return null;
      };
      await tester.tap(find.byKey(const ValueKey('ta-score-history-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byTooltip('关闭'));
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('评分记录'), findsNothing);
      f.intercept = null;
      expect(f.requests.where((r) => r.method == 'PUT'), isEmpty);
      await tester.enterText(scoreField(1), '75');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(f.scores[1], 75);
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'CSV replaces only saved students drafts and preserves failed drafts',
    (tester) async {
      final f = TaHttpFixture();
      final repo = await f.repository();
      addTearDown(repo.dispose);
      await open(tester, repo, csv: 'user_no,score\n0001,86\n0002,90');
      await tester.enterText(scoreField(1), '91');
      await tester.enterText(scoreField(2), '92');
      f.intercept = (r) async =>
          r.method == 'PUT' && (r.data as Map)['student_id'] == 2
          ? TaHttpFixture.response({}, 403)
          : null;
      await tester.tap(find.text('导入成绩'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择 CSV 文件'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('提交成绩'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认提交').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(f.scores, {1: 86});
      expect(tester.widget<TextField>(scoreField(1)).controller!.text, '86');
      expect(tester.widget<TextField>(scoreField(2)).controller!.text, '92');
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'manual refresh gets new grading counts inside the two-minute cache window',
    (tester) async {
      final f = TaHttpFixture();
      final base = await f.repository();
      addTearDown(base.dispose);
      var now = DateTime(2026, 11, 5, 10);
      final repo = TaGradingRepository(base.http, now: () => now);
      addTearDown(repo.dispose);
      await open(tester, repo);
      f.scores[1] = 88;
      now = now.add(const Duration(seconds: 6));
      await tester.tap(find.byTooltip('更新名单和成绩'));
      await tester.pumpAndSettle();
      expect(find.textContaining('已批改 1'), findsOneWidget);
      expect(tester.widget<TextField>(scoreField(1)).controller!.text, '88');
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'selected teaching course remains selected on hover dark=$dark',
      (tester) async {
        final f = TaHttpFixture();
        final repo = await f.repository();
        addTearDown(repo.dispose);
        await open(
          tester,
          repo,
          dark: dark,
          openDetail: false,
          courses: const [
            CatalogCourse(id: '91', title: '课程甲'),
            CatalogCourse(id: '92', title: '课程乙'),
          ],
        );
        final p = dark ? AppPalette.darkPalette : AppPalette.lightPalette;
        final chip = find
            .ancestor(
              of: find.text('课程甲').last,
              matching: find.byType(AppHoverSurface),
            )
            .first;
        final surface = tester.widget<AppHoverSurface>(chip);
        expect(surface.backgroundColor, p.selected);
        expect(surface.hoverColor, p.selected);
        final before = tester.getRect(chip);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(before.center);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getRect(chip), before);
        await captureDesktopUi(tester, 'ta-course-selected-hover-$dark');
        await mouse.removePointer();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('score history fits a narrow desktop window', (tester) async {
    final f = TaHttpFixture()..scores[1] = 88;
    final repo = await f.repository();
    addTearDown(repo.dispose);
    await open(tester, repo);
    tester.view.physicalSize = const Size(320, 900);
    await tester.pumpAndSettle();
    final history = find.byKey(const ValueKey('ta-score-history-1'));
    await tester.ensureVisible(history);
    await tester.pumpAndSettle();
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.text('评分记录'), findsOneWidget);
    expect(find.text('88'), findsWidgets);
    expect(tester.takeException(), isNull);
    await captureDesktopUi(tester, 'ta-score-history-narrow');
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
  });
}
