import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/homework/homework_hub_page.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_overview.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';
import 'package:xmu_rollcall/features/homework/homework_submission.dart';

import '../fixtures/preview_fonts.dart';

class _AuthRepository extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_AuthRepository()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '林同学'),
    );
  }
}

final _homework = [
  HomeworkItem(
    id: 1,
    courseId: 7,
    title: '实验二：分类模型与评估',
    courseName: '机器学习',
    dueAt: DateTime(2026, 11, 25, 23, 59),
  ),
  HomeworkItem(
    id: 2,
    courseId: 8,
    title: '软件需求分析报告',
    courseName: '软件工程',
    dueAt: DateTime(2026, 11, 27, 23, 59),
  ),
  HomeworkItem(
    id: 3,
    courseId: 7,
    title: '实验一：数据预处理',
    courseName: '机器学习',
    closed: true,
    dueAt: DateTime(2026, 11, 20, 23, 59),
  ),
];

class _Todos extends HomeworkTodosNotifier {
  @override
  Future<List<HomeworkItem>> build() async => _homework;
}

class _Overview extends HomeworkOverviewNotifier {
  @override
  Future<HomeworkOverview> build() async => HomeworkOverview(_homework);

  @override
  Future<bool> ensureFresh({bool force = false}) async => true;
}

void main() {
  setUpAll(loadDesktopPreviewFonts);
  for (final desktop in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('README homework preview desktop=$desktop dark=$dark', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = desktop
            ? const Size(1120, 780)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              secureStoreProvider.overrideWithValue(SecureStore.memory()),
              authControllerProvider.overrideWith((ref) => _Auth()),
              assistControllerProvider.overrideWith(
                (ref) => AssistController(ref, bootstrap: false),
              ),
              homeworkClockProvider.overrideWithValue(
                () => DateTime(2026, 11, 24, 10),
              ),
              homeworkTodosProvider.overrideWith(_Todos.new),
              homeworkOverviewProvider.overrideWith(_Overview.new),
              currentTeachingCoursesProvider.overrideWith(
                (ref) async => const [],
              ),
              homeworkSubmissionProvider.overrideWith(
                (ref, item) async => HomeworkSubmissionState(
                  submission: item.activityId == 1
                      ? HomeworkSubmission.unsubmitted
                      : HomeworkSubmission.submitted,
                  grading: item.activityId == 3
                      ? HomeworkGrading.graded
                      : HomeworkGrading.pending,
                  score: item.activityId == 3 ? 92 : null,
                ),
              ),
            ],
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: desktop
                      ? TargetPlatform.windows
                      : TargetPlatform.android,
                ),
                home: Scaffold(
                  body: const HomeworkHubPage(),
                  bottomNavigationBar: desktop
                      ? null
                      : AppMobileNav(
                          current: AppDestination.homework,
                          onSelect: (_) {},
                          onSearch: () {},
                        ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('实验二：分类模型与评估'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (Platform.environment['CAPTURE_README'] == '1') {
          await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: desktop ? 1 : 2);
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = await Directory(
              'build/readme-preview',
            ).create(recursive: true);
            await File(
              '${directory.path}/${desktop ? 'windows' : 'android'}-homework${dark ? '-dark' : ''}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
