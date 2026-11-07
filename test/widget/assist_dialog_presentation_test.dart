import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/assist/assist_dialogs.dart';
import '../fixtures/preview_fonts.dart';
import '../fixtures/auxiliary_dialog_capture.dart';
import '../fixtures/desktop_ui_capture.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(loadDesktopPreviewFonts);
  testWidgets(
    'import same-frame IME and button submit once, recover and retry',
    (tester) async {
      var calls = 0;
      var gate = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('打开'),
                onPressed: () => showAssistImportDialog(
                  context,
                  onImportToken: (_) async {},
                  onImportPlain: (user, password) {
                    calls++;
                    expect(user, 'fixture-user');
                    expect(password, 'fixture-password');
                    return gate.future;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('学号密码'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'fixture-user');
      await tester.enterText(
        find.byType(TextFormField).last,
        'fixture-password',
      );
      final done = tester
          .widget<TextField>(find.byType(TextField).last)
          .onSubmitted!;
      final button = tester
          .widget<AppButton>(
            find.byWidgetPredicate((w) => w is AppButton && w.label == '导入'),
          )
          .onPressed!;
      done('fixture-password');
      button();
      expect(calls, 1, reason: 'The UI has not rebuilt disabled controls yet');
      await tester.pump();
      expect(find.text('正在导入…'), findsOneWidget);
      expect(
        tester
            .widget<AppSheetCloseButton>(find.byType(AppSheetCloseButton))
            .enabled,
        isFalse,
      );
      await tester.tap(find.text('协助码'));
      await tester.pump();
      expect(find.byType(TextFormField), findsNWidgets(2));
      gate.completeError(StateError('fixture import failure'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.textContaining('fixture import failure'), findsOneWidget);
      expect(find.text('fixture-user'), findsOneWidget);
      AppToast.dismiss();
      await tester.pump();
      gate = Completer<void>();
      await tester.tap(find.text('导入'));
      await tester.pump();
      expect(calls, 2);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'pending import keeps original barrier dismissal and mounted completion',
    (tester) async {
      final gate = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('打开'),
                onPressed: () => showAssistImportDialog(
                  context,
                  onImportToken: (_) {
                    calls++;
                    return gate.future;
                  },
                  onImportPlain: (_, _) async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'fixture-code');
      await tester.tap(find.text('导入'));
      await tester.pump();
      expect(calls, 1);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(Dialog), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets('export same-frame submission preserves kind and copies once', (
    tester,
  ) async {
    final gate = Completer<String>();
    var calls = 0;
    var copies = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copies++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('打开'),
              onPressed: () => showAssistExportDialog(
                context,
                export: (kind) {
                  calls++;
                  expect(kind.name, 'account');
                  return gate.future;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('账号密码'));
    await tester.pumpAndSettle();
    final submit = tester
        .widget<AppButton>(
          find.byWidgetPredicate((w) => w is AppButton && w.label == '导出并复制'),
        )
        .onPressed!;
    submit();
    submit();
    expect(calls, 1);
    await tester.pump();
    await tester.tap(find.text('临时会话'));
    await tester.pump();
    expect(find.textContaining('长期代为登录'), findsOneWidget);
    gate.complete('preview-code');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(copies, 1);
    expect(find.byType(Dialog), findsNothing);
    AppToast.dismiss();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  for (final scenario in [
    (width: 960.0, height: 720.0, scale: 1.0, dark: false),
    (width: 960.0, height: 720.0, scale: 1.0, dark: true),
    (width: 320.0, height: 480.0, scale: 1.3, dark: false),
    (width: 320.0, height: 480.0, scale: 1.5, dark: true),
  ]) {
    testWidgets('assist dialogs retain content and cancellation $scenario', (
      tester,
    ) async {
      tester.view.physicalSize = Size(scenario.width, scenario.height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: _captureTheme(scenario.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
            child: RepaintBoundary(
              key: const ValueKey('dialog-capture'),
              child: child!,
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => showAssistImportDialog(
                        context,
                        onImportToken: (_) async {},
                        onImportPlain: (_, _) async {},
                      ),
                      child: const Text('打开导入'),
                    ),
                    TextButton(
                      onPressed: () => showAssistExportDialog(
                        context,
                        export: (_) async => 'preview-code',
                      ),
                      child: const Text('打开导出'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开导入'));
      await tester.pumpAndSettle();
      final suffix =
          '${scenario.width.toInt()}-${scenario.dark}-${scenario.scale}';
      await captureAuxiliaryDialog(tester, 'assist-import-token-$suffix');
      await tester.tap(find.text('学号密码'));
      await tester.pumpAndSettle();
      await captureAuxiliaryDialog(tester, 'assist-import-plain-$suffix');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.text('打开导出'));
      await tester.pumpAndSettle();
      await captureAuxiliaryDialog(tester, 'assist-export-session-$suffix');
      await tester.tap(find.text('账号密码'));
      await tester.pumpAndSettle();
      await captureAuxiliaryDialog(tester, 'assist-export-account-$suffix');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}

// Material's segmented label style has no family; supply the real desktop
// fallback explicitly for test rendering, where OS font fallback is absent.
ThemeData _captureTheme(bool dark) {
  final theme = dark ? AppTheme.dark() : AppTheme.light();
  final style = theme.segmentedButtonTheme.style!;
  final text = style.textStyle!.resolve({})!;
  return theme.copyWith(
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: style.copyWith(
        textStyle: WidgetStatePropertyAll(
          text.copyWith(
            fontFamily: AppTypography.family,
            fontFamilyFallback: AppTypography.fallback,
          ),
        ),
      ),
    ),
  );
}
