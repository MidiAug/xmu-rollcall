import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import '../fixtures/preview_fonts.dart';

const _clearMessage =
    '将删除已缓存的课表、成绩、作业与签到记录。'
    '手工课程安排、学期日期、地点与本机设置会保留。';

class _DialogCaptureBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['DIALOG_REVIEW_DIR'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('dialog-capture')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _open(
  WidgetTester tester, {
  required Size size,
  required double scale,
  required bool dark,
  required WidgetBuilder entry,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('dialog-capture'),
      child: MaterialApp(
        theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
          platform: TargetPlatform.windows,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: Builder(builder: entry)),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  if (Platform.environment.containsKey('DIALOG_REVIEW_DIR')) {
    _DialogCaptureBinding();
  }
  setUpAll(loadDesktopPreviewFonts);
  for (final kind in ['confirm', 'prompt', 'notice']) {
    testWidgets('repeated $kind completion keeps the underlying page', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      body: Builder(
                        builder: (pageContext) => TextButton(
                          onPressed: () {
                            if (kind == 'confirm') {
                              showAppConfirmDialog(pageContext, title: '确认操作');
                            } else if (kind == 'prompt') {
                              showAppPromptDialog(
                                pageContext,
                                title: '修改课程名称',
                                initialValue: '程序设计',
                              );
                            } else {
                              showDialog<void>(
                                context: pageContext,
                                builder: (dialogContext) => AppNoticeDialog(
                                  title: '读取失败',
                                  message: '请稍后重试',
                                  onClose: () => Navigator.pop(dialogContext),
                                ),
                              );
                            }
                          },
                          child: const Text('打开'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('进入子页'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('进入子页'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      if (kind == 'prompt') {
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.testTextInput.receiveAction(TextInputAction.done);
      } else {
        final point = tester.getCenter(
          find.text(kind == 'confirm' ? '确定' : '关闭'),
        );
        await tester.tapAt(point);
        await tester.tapAt(point);
      }
      await tester.pumpAndSettle();
      expect(find.text('打开'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final dark in [false, true]) {
    for (final sample in [
      (const Size(960, 720), 1.0),
      (const Size(320, 420), 1.5),
      (const Size(640, 300), 1.5),
    ]) {
      testWidgets(
        'confirmation fits ${sample.$1} scale=${sample.$2} dark=$dark',
        (tester) async {
          bool? result;
          await _open(
            tester,
            size: sample.$1,
            scale: sample.$2,
            dark: dark,
            entry: (context) => TextButton(
              onPressed: () async => result = await showAppConfirmDialog(
                context,
                title: '清除本机课程数据？',
                message: _clearMessage,
                confirmLabel: '清除',
                destructive: true,
              ),
              child: const Text('打开'),
            ),
          );
          await _capture(
            tester,
            'confirm-${sample.$1.width}-${sample.$1.height}-$dark',
          );
          expect(tester.takeException(), isNull);
          final dialog = tester.getRect(find.byType(Dialog));
          for (final label in ['取消', '清除']) {
            final rect = tester.getRect(find.text(label));
            expect(dialog.contains(rect.center), isTrue);
            expect(rect.bottom, lessThanOrEqualTo(sample.$1.height));
          }
          await tester.tap(find.text('取消'));
          await tester.pumpAndSettle();
          expect(result, isFalse);
          expect(find.byType(Dialog), findsNothing);
        },
      );
    }
    testWidgets(
      'notice remains readable and dismissible in a short window $dark',
      (tester) async {
        await _open(
          tester,
          size: const Size(320, 400),
          scale: 2,
          dark: dark,
          entry: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AppNoticeDialog(
                title: '暂时无法读取评分记录',
                message: '网络连接失败，请检查网络后重试。已加载的名单和输入的成绩仍然保留。',
                onClose: () => Navigator.pop(dialogContext),
              ),
            ),
            child: const Text('打开'),
          ),
        );
        await _capture(tester, 'notice-320-$dark');
        expect(tester.takeException(), isNull);
        final closeBeforeScroll = tester.getRect(find.text('关闭'));
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -180),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('关闭')), closeBeforeScroll);
        await _capture(tester, 'notice-scrolled-320-$dark');
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
      },
    );
    testWidgets('prompt validation, keyboard submit and cancellation $dark', (
      tester,
    ) async {
      String? result;
      await _open(
        tester,
        size: const Size(320, 520),
        scale: 1.5,
        dark: dark,
        entry: (context) => TextButton(
          onPressed: () async => result = await showAppPromptDialog(
            context,
            title: '修改课程名称',
            initialValue: '软件工程',
            labelText: '课程名称',
            validator: (value) => value.isEmpty ? '请输入课程名称' : null,
          ),
          child: const Text('打开'),
        ),
      );
      await tester.enterText(find.byType(TextField), '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('请输入课程名称'), findsOneWidget);
      await _capture(tester, 'prompt-invalid-320-$dark');
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), '程序设计');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(result, '程序设计');
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
