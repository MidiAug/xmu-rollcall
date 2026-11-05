import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/network/rate_limiter.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import '../fixtures/exam_adapter.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/exams/exam_models.dart';
import 'package:xmu_rollcall/features/exams/exam_page.dart';
import 'package:xmu_rollcall/features/exams/exam_providers.dart';
import '../fixtures/preview_fonts.dart';
import 'package:xmu_rollcall/features/campus/campus_tools_page.dart';

class Repo extends Fake implements AuthRepository {}

class Auth extends AuthController {
  Auth() : super(Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: 'Test'),
    );
  }
}

void main() {
  setUpAll(loadDesktopPreviewFonts);
  for (final origin in ['retry', 'header']) {
    testWidgets('$origin shares request progress, failures and throttling', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      var now = DateTime(2026, 11, 10, 9);
      final adapter = ExamAdapter()..failUnarranged = true;
      final captureKey = GlobalKey();
      Future<void> captureProgress(String name) async {
        if (origin != 'retry' || Platform.environment['CAPTURE_EXAM_UI'] != '1') {
          return;
        }
        await tester.runAsync(() async {
          final boundary =
              captureKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/exam-retry-review').create(recursive: true);
          await File(
            'build/exam-retry-review/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith((ref) => Auth()),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(
              ref,
              bootstrap: false,
              initial: const AssistUiState(ready: true),
            ),
          ),
          examClockProvider.overrideWithValue(() => now),
          academicIdentityResolverProvider.overrideWithValue(
            (_) async => AcademicIdentity(
              username: 'synthetic',
              isCurrent: () async => true,
            ),
          ),
          academicSessionFactoryProvider.overrideWithValue(
            () => AcademicSession(
              store: SecureStore.memory({SecureStore.keyUserId: '1'}),
              dio: Dio()..httpClientAdapter = adapter,
              limiter: RateLimiter(minInterval: Duration.zero),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: RepaintBoundary(key: captureKey, child: const ExamPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('重试'), findsOneWidget);
      now = now.add(const Duration(seconds: 16));
      adapter.gate = Completer<void>();
      final refresh = find.byType(AppRefreshButton);
      await tester.tap(origin == 'retry' ? find.text('重试') : refresh);
      await tester.pump();
      expect(find.text('正在读取考试安排…'), findsOneWidget);
      expect(tester.widget<AppRefreshButton>(refresh).busy, isTrue);
      final iconButton = find.descendant(
        of: refresh,
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(iconButton).onPressed, isNull);
      expect(find.text('重试'), findsNothing);
      await tester.pump(const Duration(milliseconds: 250));
      await captureProgress('loading');
      adapter.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('暂时无法读取考试安排'), findsOneWidget);
      expect(tester.widget<AppRefreshButton>(refresh).busy, isFalse);
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('请间隔15秒再更新考试安排'), findsOneWidget);
      await captureProgress('throttled');
      expect(tester.widget<IconButton>(iconButton).onPressed, isNotNull);
      now = now.add(const Duration(seconds: 16));
      adapter.failUnarranged = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('暂时无法读取考试安排'), findsNothing);
      expect(find.text('已排课程'), findsOneWidget);
      expect(tester.widget<AppRefreshButton>(refresh).busy, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final mobile in [true, false]) {
    for (final dark in [false, true]) {
      testWidgets(
        'exam groups and cache on ${mobile ? 'phone' : 'desktop'} ${dark ? 'dark' : 'light'}',
        (tester) async {
          final now = DateTime(2026, 11, 10, 9);
          final snapshot = ExamSnapshot(
            term: '20261',
            at: now,
            exams: [
              parseAcademicExam({
                'KSRWID': 'a',
                'KCM': '计算机网络',
                'KSRQ': '2026-11-10',
                'KSSJMS': '08:00-10:00',
                'JASMC': '文宣楼（4号楼）B404',
                'ZWH': '25',
                'KSXS_DISPLAY': '闭卷',
              }),
              parseAcademicExam({
                'KSRWID': 'b',
                'KCM': '软件工程与面向对象程序设计课程综合实践',
                'KSRQ': '2026-11-12',
                'KSSJMS': '14:00-16:00',
                'JASMC': '学武楼（1号楼）A301',
                'KSXS_DISPLAY': '开卷',
              }),
              parseAcademicExam({
                'KSRWID': 'c',
                'KCM': '数学分析',
                'KSRQ': '2026-11-09',
                'KSSJMS': '08:00-10:00',
              }),
              const AcademicExam(id: 'd', course: '形势与政策'),
            ],
          );
          SharedPreferences.setMockInitialValues({
            examCacheKey(1, 1, '20261'): jsonEncode(snapshot.toJson()),
          });
          tester.view.physicalSize = mobile
              ? const Size(390, 844)
              : const Size(1100, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          Future<void> capture(String page) async {
            if (Platform.environment['CAPTURE_EXAM_UI'] == '1') {
              await tester.runAsync(() async {
                final boundary =
                    key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final image = await boundary.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final folder = Directory('build/exam-ui-review');
                await folder.create(recursive: true);
                await File(
                  '${folder.path}/${page == 'tools' ? 'tools-' : ''}${mobile ? 'phone' : 'desktop'}-${dark ? 'dark' : 'light'}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          }

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authControllerProvider.overrideWith((ref) => Auth()),
                assistControllerProvider.overrideWith(
                  (ref) => AssistController(
                    ref,
                    bootstrap: false,
                    initial: const AssistUiState(ready: true),
                  ),
                ),
                examClockProvider.overrideWithValue(() => now),
                academicIdentityResolverProvider.overrideWithValue(
                  (_) => throw StateError(
                    'fresh cache must not resolve credentials',
                  ),
                ),
              ],
              child: MaterialApp(
                theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: mobile
                      ? TargetPlatform.android
                      : TargetPlatform.windows,
                ),
                home: RepaintBoundary(key: key, child: const ExamPage()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('1门'), findsOneWidget);
          expect(find.text('2场'), findsOneWidget);
          expect(find.text('1场'), findsOneWidget);
          expect(find.textContaining('上次核对 2026-11-10 09:00'), findsOneWidget);
          expect(find.textContaining('正在考试'), findsNothing);
          expect(find.text('文宣楼（4号楼）B404'), findsOneWidget);
          expect(find.text('座位 25'), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (w) => w is Tooltip && w.message == '软件工程与面向对象程序设计课程综合实践',
            ),
            mobile ? findsOneWidget : findsNothing,
          );
          expect(
            find.byWidgetPredicate((w) => w is Tooltip && w.message == '计算机网络'),
            findsNothing,
          );
          expect(
            tester
                .widgetList<Text>(find.byType(Text))
                .map((w) => w.data ?? '')
                .where((s) => RegExp('[·•⋅]').hasMatch(s)),
            isEmpty,
          );
          expect(tester.takeException(), isNull);
          await capture('exams');
          await tester.scrollUntilVisible(find.text('数学分析'), 200);
          expect(find.text('按公布的结束时间归类'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            MaterialApp(
              theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                platform: mobile
                    ? TargetPlatform.android
                    : TargetPlatform.windows,
              ),
              home: RepaintBoundary(key: key, child: const CampusToolsPage()),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('考试安排'), findsOneWidget);
          expect(find.text('GPA 计算器'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture('tools');
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
