import 'package:xmu_rollcall/features/lectures/lecture_requirement_provider.dart';
import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/browser/browser_session.dart';
import 'package:xmu_rollcall/features/lectures/lecture_page.dart';
import 'package:xmu_rollcall/features/lectures/lecture_provider.dart';
import '../fixtures/lecture_fixture.dart';
import '../fixtures/desktop_ui_capture.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(loadDesktopUiCaptureFonts);
  Future<void> pump(
    WidgetTester tester,
    LectureFixtureClient client, {
    double width = 1104,
    bool dark = false,
    Widget page = const LecturesPage(),
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          browserIdentityProvider.overrideWithValue((
            ownerId: 1,
            userId: 1,
            assistId: null,
          )),
          secureStoreProvider.overrideWithValue(
            SecureStore.memory({'lecture_session_v1_1_1': 'fixture-session'}),
          ),
          academicIdentityResolverProvider.overrideWithValue(
            (uid) async => AcademicIdentity(
              username: 'fixture-student',
              isCurrent: () async => true,
            ),
          ),
          lectureClientFactoryProvider.overrideWithValue(() => client),
          lectureRequirementReaderProvider.overrideWithValue(
            LectureRequirementFixtureReader.new,
          ),
        ],
        child: MaterialApp(
          theme: desktopCaptureTheme(
            (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: width < 500
                  ? TargetPlatform.android
                  : TargetPlatform.windows,
            ),
          ),
          home: RepaintBoundary(
            key: const ValueKey('desktop-ui-capture'),
            child: page,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 390.0, 1104.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'native lecture filters, attendance and content $width $dark',
        (tester) async {
          final client = LectureFixtureClient();
          await pump(tester, client, width: width, dark: dark);
          expect(find.text('学术讲座'), findsOneWidget);
          expect(client.lists, 1);
          expect(find.text('15/20'), findsOneWidget);
          expect(find.text('已参加'), findsOneWidget);
          expect(find.textContaining('2030-01-01 14:00'), findsOneWidget);
          expect(find.text('全部讲座'), findsNothing);
          expect(find.text('我的签到'), findsNothing);
          expect(find.text('报名'), findsNothing);
          expect(find.text('我的活动'), findsNothing);
          await captureDesktopUi(tester, 'lectures-${width.toInt()}-$dark');
          await tester.tap(find.text('加载更多'));
          await tester.pumpAndSettle();
          expect(find.text('测试学术讲座'), findsNWidgets(2));
          expect(client.lists, 2);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('plan detail is a read-only notice, with no booking controls', (
    tester,
  ) async {
    await pump(tester, LectureFixtureClient());
    await tester.tap(find.text('培养方案要求'));
    await tester.pumpAndSettle();
    expect(find.textContaining('另需提交总结'), findsOneWidget);
    expect(find.text('取消报名'), findsNothing);
    expect(find.text('确认报名'), findsNothing);
  });
}
