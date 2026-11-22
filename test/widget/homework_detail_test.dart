import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/storage/json_disk_cache.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/homework/homework_course_page.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_overview.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import '../fixtures/preview_fonts.dart';
import '../fixtures/desktop_ui_capture.dart';

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

void main() {
  initializeDesktopUiCapture();
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('detail to course to another detail preserves course context', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const seed = HomeworkItem(
      id: 7,
      title: 'Essay',
      courseId: 3,
      courseName: 'English',
    );
    const next = HomeworkItem(id: 8, title: 'Next essay');
    await JsonDiskCache.writeList('course_homework_1_3', [next.toJson()]);
    await JsonDiskCache.writeList('homework_todos_1', []);
    final opened = <HomeworkDetailKey>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          currentTeachingCoursesProvider.overrideWith((ref) async => const []),
          homeworkSubmissionProvider.overrideWith(
            (ref, key) async => const HomeworkSubmissionState(
              submission: HomeworkSubmission.unknown,
            ),
          ),
          homeworkDetailProvider.overrideWith((ref, key) async {
            opened.add(key);
            return key.seed!;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const HomeworkDetailPage(seed: seed),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('课程作业'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeworkCoursePage), findsOneWidget);
    await tester.tap(find.text('Next essay'));
    await tester.pumpAndSettle();
    expect(opened.last.activityId, 8);
    expect(opened.last.seed!.courseId, 3);
    expect(opened.last.seed!.courseName, 'English');
    expect(find.text('Next essay'), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeworkCoursePage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [320.0, 960.0]) {
    testWidgets(
      'submission and grading belong to the assignment summary at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const seed = HomeworkItem(
          id: 7,
          title: 'Essay',
          courseId: 3,
          courseName: 'English',
          type: 'homework',
          status: 'open',
          description: 'Assignment instructions',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith((ref) => _Auth()),
              currentTeachingCoursesProvider.overrideWith(
                (ref) async => const [],
              ),
              homeworkDetailProvider.overrideWith((ref, key) async => seed),
              homeworkSubmissionProvider.overrideWith(
                (ref, key) async => const HomeworkSubmissionState(
                  submission: HomeworkSubmission.submitted,
                  grading: HomeworkGrading.graded,
                  score: 86.5,
                ),
              ),
            ],
            child: MaterialApp(
              theme: width < 600 ? AppTheme.dark() : AppTheme.light(),
              home: const HomeworkDetailPage(seed: seed),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('已提交'), findsOneWidget);
        expect(find.text('open'), findsNothing);
        expect(find.text('homework'), findsNothing);
        expect(find.text('已批改 86.5 分'), findsOneWidget);
        final summary = find.byKey(const ValueKey('homework-detail-summary-7'));
        for (final label in ['Essay', 'English', '已提交', '已批改 86.5 分']) {
          expect(
            find.descendant(of: summary, matching: find.text(label)),
            findsOneWidget,
          );
        }
        expect(
          tester.getBottomLeft(summary).dy,
          lessThan(tester.getTopLeft(find.text('Assignment instructions')).dy),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final (width, scale, dark) in [
    (320.0, 1.5, true),
    (960.0, 1.0, false),
  ]) {
    for (final content in ['empty', 'description', 'attachments', 'both']) {
      testWidgets(
        'detail shows only supplied reading content $content at $width',
        (tester) async {
          tester.view.physicalSize = Size(width, width >= 960 ? 720 : 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final hasDescription = content == 'description' || content == 'both';
          final hasAttachments = content == 'attachments' || content == 'both';
          final launched = <String>[];
          const launchChannel = MethodChannel(
            'plugins.flutter.io/url_launcher',
          );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            launchChannel,
            (call) async {
              if (call.method == 'launch') {
                launched.add((call.arguments as Map)['url'] as String);
              }
              return true;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(launchChannel, null),
          );
          final seed = HomeworkItem(
            id: 17,
            title: content == 'both' ? '面向对象程序设计：需求分析、实现与测试报告' : '实验报告',
            courseId: 3,
            courseName: '软件工程与面向对象程序设计课程综合实践',
            dueAt: DateTime(2026, 11, 9, 23, 59),
            type: 'homework',
            description: hasDescription
                ? '<p>请完成需求分析与测试报告。</p><p>保留实现与验证依据。</p>'
                : '<p>&nbsp;</p>',
            attachments: hasAttachments
                ? [
                    HomeworkAttachment(
                      name: '实验要求与报告模板.pdf',
                      size: 102400,
                      url: Uri.parse(
                        'https://lnt.xmu.edu.cn/files/worksheet.pdf',
                      ),
                    ),
                    const HomeworkAttachment(name: '补充材料.txt'),
                  ]
                : const [],
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith((ref) => _Auth()),
                currentTeachingCoursesProvider.overrideWith(
                  (ref) async => const [],
                ),
                homeworkDetailProvider.overrideWith((ref, key) async => seed),
                homeworkSubmissionProvider.overrideWith(
                  (ref, key) async => content == 'empty'
                      ? const HomeworkSubmissionState(
                          submission: HomeworkSubmission.unsubmitted,
                        )
                      : const HomeworkSubmissionState(
                          submission: HomeworkSubmission.submitted,
                          grading: HomeworkGrading.graded,
                          score: 92,
                        ),
                ),
              ],
              child: MaterialApp(
                theme:
                    desktopCaptureTheme(
                      dark ? AppTheme.dark() : AppTheme.light(),
                    ).copyWith(
                      platform: width < 600
                          ? TargetPlatform.android
                          : TargetPlatform.windows,
                    ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: RepaintBoundary(
                    key: const ValueKey('desktop-ui-capture'),
                    child: child!,
                  ),
                ),
                home: HomeworkDetailPage(seed: seed),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(content == 'empty' ? '未提交' : '已提交'), findsOneWidget);
          expect(
            find.text('已批改 92 分'),
            content == 'empty' ? findsNothing : findsOneWidget,
          );
          expect(find.text('截止 2026-11-09 23:59'), findsOneWidget);
          expect(
            find.text('作业说明'),
            hasDescription ? findsOneWidget : findsNothing,
          );
          expect(
            find.byKey(const ValueKey('homework-description-17')),
            hasDescription ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('附件（2）'),
            hasAttachments ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('暂无作业说明和附件'),
            content == 'empty' ? findsOneWidget : findsNothing,
          );
          expect(find.text('暂无附件'), findsNothing);
          expect(find.text('提交作业'), findsNothing);
          expect(find.text('编辑作业'), findsNothing);
          if (content == 'empty' && width >= 960) {
            expect(
              tester
                  .getSize(
                    find.byKey(const ValueKey('homework-detail-content-17')),
                  )
                  .height,
              lessThan(280),
            );
          }
          if (content == 'both') {
            final title = tester.renderObject<RenderParagraph>(
              find.text(seed.title),
            );
            expect(title.didExceedMaxLines, isFalse);
          }
          await captureDesktopUi(
            tester,
            'homework-detail-$content-${width.toInt()}',
          );
          if (hasAttachments) {
            final pageScroll = find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first;
            await tester.scrollUntilVisible(
              find.byTooltip('下载附件'),
              160,
              scrollable: pageScroll,
            );
            await tester.pumpAndSettle();
            expect(find.text('100.0 KB'), findsOneWidget);
            await tester.tap(find.byTooltip('下载附件'));
            await tester.pumpAndSettle();
            expect(launched, ['https://lnt.xmu.edu.cn/files/worksheet.pdf']);
            await tester.scrollUntilVisible(
              find.text('补充材料.txt'),
              100,
              scrollable: pageScroll,
            );
            expect(find.text('平台未提供下载链接'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'failed detail keeps a separate seed summary and retries the real detail provider',
    (tester) async {
      var reads = 0;
      const seed = HomeworkItem(
        id: 7,
        title: '缓存中的作业',
        courseId: 3,
        courseName: '示例课程',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _Auth()),
            currentTeachingCoursesProvider.overrideWith(
              (ref) async => const [],
            ),
            homeworkSubmissionProvider.overrideWith(
              (ref, key) async => const HomeworkSubmissionState(
                submission: HomeworkSubmission.unsubmitted,
              ),
            ),
            homeworkDetailProvider.overrideWith((ref, key) async {
              if (++reads == 1) throw StateError('网络暂不可用');
              return seed.copyWith(title: '重新读取的作业', description: '重新读取的说明');
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const HomeworkDetailPage(seed: seed),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('以下为列表缓存摘要'), findsOneWidget);
      expect(find.text('缓存中的作业'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('缓存中的作业'),
          matching: find.byKey(const ValueKey('homework-detail-summary-7')),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('重新读取的作业'), findsOneWidget);
      expect(find.text('重新读取的说明'), findsOneWidget);
      expect(find.text('以下为列表缓存摘要'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('detail shows 查看该课全部 when courseId present', (tester) async {
    final seed = HomeworkItem(
      id: 7,
      title: 'Essay',
      courseId: 3,
      courseName: 'English',
      dueAt: DateTime.utc(2026, 10, 1),
      status: 'open',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeworkDetailProvider.overrideWith((ref, key) async => seed),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: HomeworkDetailPage(seed: seed),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('课程作业'), findsOneWidget);
    expect(find.text('Essay'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('detail hides 查看该课全部 without courseId', (tester) async {
    final seed = const HomeworkItem(id: 8, title: 'No course');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeworkDetailProvider.overrideWith((ref, key) async => seed),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: HomeworkDetailPage(seed: seed),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('课程作业'), findsNothing);
    expect(find.textContaining('未提供课程信息'), findsOneWidget);
  });

  testWidgets(
    'detail shows seed summary and static skeleton while loading, then keeps content on background reload',
    (tester) async {
      const seed = HomeworkItem(
        id: 42,
        title: '数据结构作业',
        courseId: 9,
        courseName: '数据结构',
      );
      const detailKey = HomeworkDetailKey(
        activityId: 42,
        courseId: 9,
        seed: seed,
      );
      final firstFetch = Completer<HomeworkItem>();
      final secondFetch = Completer<HomeworkItem>();
      var fetchCount = 0;

      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => _Auth()),
          currentTeachingCoursesProvider.overrideWith((ref) async => const []),
          homeworkSubmissionProvider.overrideWith(
            (ref, key) async => const HomeworkSubmissionState(
              submission: HomeworkSubmission.unsubmitted,
            ),
          ),
          homeworkDetailProvider.overrideWith((ref, key) {
            fetchCount++;
            return fetchCount == 1 ? firstFetch.future : secondFetch.future;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const HomeworkDetailPage(seed: seed),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('homework-detail-summary-42')),
        findsOneWidget,
      );
      expect(find.text('数据结构作业'), findsOneWidget);
      expect(find.text('数据结构'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('homework-detail-skeleton-42')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('暂无作业说明和附件'), findsNothing);

      firstFetch.complete(seed.copyWith(description: '请提交红黑树实现与复杂度分析。'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('homework-detail-skeleton-42')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('homework-description-42')),
        findsOneWidget,
      );
      expect(find.text('请提交红黑树实现与复杂度分析。'), findsOneWidget);

      container.invalidate(homeworkDetailProvider(detailKey));
      await tester.pump();

      final reloading = container.read(homeworkDetailProvider(detailKey));
      expect(reloading.isLoading, isTrue);
      expect(reloading.hasValue, isTrue);
      expect(
        find.byKey(const ValueKey('homework-description-42')),
        findsOneWidget,
      );
      expect(find.text('请提交红黑树实现与复杂度分析。'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('homework-detail-skeleton-42')),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);

      secondFetch.complete(seed.copyWith(description: '更新后的作业要求。'));
      await tester.pumpAndSettle();

      expect(find.text('更新后的作业要求。'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
