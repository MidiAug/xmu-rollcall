import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/grades/gpa_page.dart';
import 'package:xmu_rollcall/features/grades/grade_models.dart';
import 'package:xmu_rollcall/features/grades/grade_providers.dart';
import '../fixtures/preview_fonts.dart';

class Repo extends Fake implements AuthRepository {}

class Auth extends AuthController {
  Auth() : super(Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

class Grades extends GradeNotifier {
  @override
  Future<GradeSnapshot> build() async => GradeSnapshot(
    at: DateTime(2026, 10, 28, 10),
    term: '20261',
    records: [
      const GradeRecord({
        'WID': 'a',
        'KCM': '程序设计基础',
        'XNXQDM': '2026-2027-1',
        'XF': 2,
        'JDF': 4,
        'ZCJ': 95,
      }),
      const GradeRecord({
        'WID': 'b',
        'KCLBDM_DISPLAY': '通识教育课程',
        'KCM': '课程名称很长的另一门测试课程用于检查边界',
        'XNXQDM': '2025-2026-2',
        'XF': 1,
        'JDF': 2,
        'ZCJ': 75,
      }),
    ],
  );
}

void main() {
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    final file = File(
      'D:/Dev/Flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (file.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final width in [320.0, 384.0, 960.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'GPA layout, selection and cached metadata at $width dark=$dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith((ref) => Auth()),
                gradeSnapshotProvider.overrideWith(Grades.new),
              ],
              child: RepaintBoundary(
                key: key,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                    platform: width < 600
                        ? TargetPlatform.android
                        : TargetPlatform.windows,
                  ),
                  home: const GpaPage(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('3.33'), findsOneWidget);
          expect(find.textContaining('2026-10-28 10:00'), findsOneWidget);
          expect(tester.takeException(), isNull);
          Future<void> capture(String name) async {
            if (Platform.environment['CAPTURE_GPA_UI'] != '1') return;
            await tester.runAsync(() async {
              final render =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final im = await render.toImage();
              final data = await im.toByteData(format: ui.ImageByteFormat.png);
              await Directory('build/gpa-ui-review').create(recursive: true);
              await File(
                'build/gpa-ui-review/$name-$width-$dark.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              im.dispose();
            });
          }

          await capture('gpa');
          await tester.ensureVisible(find.byKey(const ValueKey('grade-b')));
          await tester.tap(find.byKey(const ValueKey('grade-b')));
          await tester.pumpAndSettle();
          expect(find.text('4.00'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('grade-b')));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const ValueKey('grade-range')));
          await tester.tap(find.text('学年'));
          await tester.pumpAndSettle();
          expect(find.text('4.00'), findsOneWidget);
          expect(find.byKey(const ValueKey('grade-year-2026')), findsOneWidget);
          expect(find.byKey(const ValueKey('grade-year-2025')), findsOneWidget);
          expect(find.byKey(const ValueKey('grade-year-2024')), findsNothing);
          expect(find.text('近几个学年'), findsNothing);
          await tester.tap(find.byKey(const ValueKey('grade-year-2025')));
          await tester.pumpAndSettle();
          expect(find.text('3.33'), findsOneWidget);
          await capture('gpa-years');
          await tester.tap(find.byKey(const ValueKey('grade-year-2026')));
          await tester.pumpAndSettle();
          expect(find.text('2.00'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('grade-year-2025')));
          await tester.pumpAndSettle();
          expect(find.text('选择学年后查看课程与 GPA'), findsOneWidget);
          expect(find.byKey(const ValueKey('grade-b')), findsNothing);
          await tester.tap(find.byKey(const ValueKey('grade-year-2025')));
          await tester.pumpAndSettle();
          expect(find.text('2.00'), findsOneWidget);
          await tester.tap(find.text('近学期'));
          await tester.pumpAndSettle();
          expect(find.text('3.33'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('grade-recent')));
          await tester.pumpAndSettle();
          expect(find.text('近 3 个学期'), findsNothing);
          await tester.tap(find.text('近 1 个学期').last);
          await tester.pumpAndSettle();
          expect(find.text('4.00'), findsOneWidget);
          await tester.tap(find.text('总绩点'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('排除通识课程'));
          await tester.pumpAndSettle();
          expect(find.text('4.00'), findsOneWidget);
          await tester.ensureVisible(find.text('恢复默认选择'));
          await tester.tap(find.text('恢复默认选择'));
          await tester.pumpAndSettle();
          expect(find.text('3.33'), findsOneWidget);
          await tester.ensureVisible(find.text('计算规则与来源'));
          await tester.tap(find.text('计算规则与来源'));
          await tester.pumpAndSettle();
          expect(find.text('本科生成绩管理办法'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
