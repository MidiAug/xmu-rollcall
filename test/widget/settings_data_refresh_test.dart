import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/app/app_settings_glyph.dart';
import 'package:xmu_rollcall/app/providers.dart';
import 'package:xmu_rollcall/core/storage/secure_store.dart';
import 'package:xmu_rollcall/core/theme/app_icons.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/academic/academic_access.dart';
import 'package:xmu_rollcall/features/academic/academic_identity.dart';
import 'package:xmu_rollcall/features/academic/academic_session.dart';
import 'package:xmu_rollcall/features/assist/assist_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_controller.dart';
import 'package:xmu_rollcall/features/auth/auth_models.dart';
import 'package:xmu_rollcall/features/auth/auth_repository.dart';
import 'package:xmu_rollcall/features/grades/academic_grade_reader.dart';
import 'package:xmu_rollcall/features/grades/grade_models.dart';
import 'package:xmu_rollcall/features/grades/grade_release_policy.dart';
import 'package:xmu_rollcall/features/grades/grade_providers.dart';
import 'package:xmu_rollcall/features/exams/academic_exam_reader.dart';
import 'package:xmu_rollcall/features/exams/exam_cache.dart';
import 'package:xmu_rollcall/features/exams/exam_models.dart';
import 'package:xmu_rollcall/features/exams/exam_providers.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account.dart';
import 'package:xmu_rollcall/features/settings/settings_data_page.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

class _Repo extends Fake implements AuthRepository {}

class _Auth extends AuthController {
  _Auth() : super(_Repo()) {
    state = const AuthState(
      status: AuthStatus.signedIn,
      profile: UserProfile(id: 1, name: '主账号'),
    );
  }
}

class _Grades extends AcademicGradeReader {
  _Grades(super.session);
  final calls = <int>[];
  bool fail = false;
  @override
  Future<AcademicGradeResult> fetch(
    int uid, {
    CookieJar? sso,
    String? username,
    String? password,
    bool recent = false,
  }) async {
    calls.add(uid);
    if (fail) throw StateError('read failed');
    return const AcademicGradeResult(
      rows: [],
      replacedTerms: {},
      complete: true,
    );
  }
}

class _Exams extends AcademicExamReader {
  _Exams(super.session);
  final calls = <int>[];
  bool fail = false;
  @override
  Future<ExamSnapshot> fetch(
    int uid, {
    required String term,
    required DateTime at,
    CookieJar? sso,
    String? username,
    String? password,
  }) async {
    calls.add(uid);
    if (fail) throw StateError('read failed');
    return ExamSnapshot(term: term, at: at, exams: []);
  }
}

void main() {
  initializeDesktopUiCapture();
  setUpAll(loadDesktopPreviewFonts);
  final now = DateTime(2026, 11, 22, 12);
  for (final uid in [1, 2]) {
    for (final cache in [
      'missing',
      'fresh',
      'old',
      'release',
      'failure',
      'exam-failure',
    ]) {
      testWidgets(
        'diagnostics update uses one scoped read uid=$uid cache=$cache',
        (tester) async {
          final at = (cache == 'old' || cache == 'release')
              ? now.subtract(const Duration(days: 10))
              : now.subtract(const Duration(minutes: 1));
          final grade = GradeSnapshot(
            at: at,
            term: '20261',
            records: [],
            exams: cache == 'release'
                ? AcademicExamDates(
                    term: '20261',
                    at: at,
                    dates: [now.subtract(const Duration(days: 2))],
                  )
                : null,
          );
          final exam = ExamSnapshot(at: at, term: '20261', exams: []);
          SharedPreferences.setMockInitialValues({
            if (cache != 'missing')
              gradeCacheKey(1, uid): jsonEncode(grade.toJson()),
            if (cache != 'missing')
              examCacheKey(1, uid, '20261'): jsonEncode(exam.toJson()),
          });
          final store = SecureStore.memory();
          final grades = _Grades(AcademicSession(store: store))
            ..fail = cache == 'failure';
          final exams = _Exams(AcademicSession(store: store))
            ..fail = cache == 'exam-failure';
          final container = ProviderContainer(
            overrides: [
              secureStoreProvider.overrideWithValue(store),
              authControllerProvider.overrideWith((ref) => _Auth()),
              assistControllerProvider.overrideWith(
                (ref) => AssistController(
                  ref,
                  bootstrap: false,
                  initial: const AssistUiState(ready: true),
                ),
              ),
              academicIdentityResolverProvider.overrideWithValue(
                (_) async => AcademicIdentity(isCurrent: () async => true),
              ),
              gradeClockProvider.overrideWithValue(() => now),
              examClockProvider.overrideWithValue(() => now),
              gradeReaderProvider.overrideWithValue(() => grades),
              examReaderProvider.overrideWithValue(() => exams),
            ],
          );
          addTearDown(container.dispose);
          container.read(selectedRollcallAccountProvider.notifier).state =
              uid == 1 ? null : uid;
          tester.view.physicalSize = const Size(960, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: RepaintBoundary(
                key: const ValueKey('desktop-ui-capture'),
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light(),
                  home: const SettingsDataPage(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(container.exists(gradeSnapshotProvider), isFalse);
          expect(container.exists(examSnapshotProvider), isFalse);
          expect(grades.calls, isEmpty);
          expect(exams.calls, isEmpty);
          await captureDesktopUi(tester, 'data-r22-initial-$uid-$cache');
          final gradeButton = find.byKey(
            const ValueKey('academic-grades-update'),
          );
          await tester.ensureVisible(gradeButton);
          await tester.tap(gradeButton);
          await tester.pumpAndSettle();
          expect(grades.calls, [uid]);
          expect(exams.calls, isEmpty);
          if (cache == 'failure') {
            expect(find.text('更新失败，已有数据仍保留'), findsOneWidget);
            final prefs = await SharedPreferences.getInstance();
            expect(
              GradeSnapshot.fromJson(
                jsonDecode(prefs.getString(gradeCacheKey(1, uid))!)
                    as Map<String, dynamic>,
              ).at,
              at,
            );
          } else {
            expect(find.text('已更新'), findsOneWidget);
            await tester.tap(gradeButton);
            await tester.pumpAndSettle();
            expect(grades.calls, [
              uid,
            ], reason: 'The existing manual throttle is retained');
          }
          final examButton = find.byKey(
            const ValueKey('academic-exams-update'),
          );
          await tester.ensureVisible(examButton);
          await tester.tap(examButton);
          await tester.pumpAndSettle();
          expect(exams.calls, [uid]);
          if (cache == 'exam-failure') {
            expect(find.text('更新失败，已有数据仍保留'), findsOneWidget);
            final prefs = await SharedPreferences.getInstance();
            expect(readExamCache(prefs, 1, uid, '20261')!.at, at);
          }
          await captureDesktopUi(tester, 'data-r22-$uid-$cache');
          if (uid == 1 && cache == 'fresh') {
            final clear = find.text('清除本机课程数据');
            await tester.ensureVisible(clear);
            await tester.tap(clear);
            await tester.pumpAndSettle();
            await captureDesktopUi(tester, 'data-clear-r22');
            await tester.tap(find.byTooltip('关闭'));
            await tester.pumpAndSettle();
            final prefs = await SharedPreferences.getInstance();
            expect(prefs.getString(gradeCacheKey(1, uid)), isNotNull);
          }

          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'SettingsDataPage renders AppSettingsGlyphs without legacy filled service icons',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = SecureStore.memory();
      final container = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(store),
          authControllerProvider.overrideWith((ref) => _Auth()),
          assistControllerProvider.overrideWith(
            (ref) => AssistController(
              ref,
              bootstrap: false,
              initial: const AssistUiState(ready: true),
            ),
          ),
          academicIdentityResolverProvider.overrideWithValue(
            (_) async => AcademicIdentity(isCurrent: () async => true),
          ),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(960, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SettingsDataPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final renderedKinds = <AppSettingsGlyphKind>{};
      void collectGlyphs() {
        for (final glyph in tester.widgetList<AppSettingsGlyph>(
          find.byType(AppSettingsGlyph),
        )) {
          renderedKinds.add(glyph.kind);
        }
      }

      collectGlyphs();
      expect(find.byIcon(AppIcons.serviceGpa, skipOffstage: false), findsNothing);
      expect(
        find.byIcon(AppIcons.serviceExams, skipOffstage: false),
        findsNothing,
      );

      final exportRow = find.text('导出诊断日志');
      await tester.scrollUntilVisible(
        exportRow,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      collectGlyphs();

      expect(renderedKinds, {
        AppSettingsGlyphKind.calendar,
        AppSettingsGlyphKind.chartBar,
        AppSettingsGlyphKind.fileText,
        AppSettingsGlyphKind.trash,
        AppSettingsGlyphKind.window,
        AppSettingsGlyphKind.trayUp,
      });
      expect(find.byIcon(AppIcons.serviceGpa, skipOffstage: false), findsNothing);
      expect(
        find.byIcon(AppIcons.serviceExams, skipOffstage: false),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
