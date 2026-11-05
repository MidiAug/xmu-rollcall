import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/close_ask_dialog.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  setUpAll(loadDesktopPreviewFonts);
  for (final task in ['值守', '检测']) {
    for (final busy in [true, false]) {
      testWidgets(
        'close $task running=$busy uses the matching task and preserves actions',
        (tester) async {
          CloseAskResult? result;
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('close-capture'),
              child: MaterialApp(
                theme: AppTheme.light(),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        result = await showCloseAskDialog(
                          context,
                          busy: busy,
                          taskLabel: task,
                          rememberDefaultChecked: true,
                        );
                      },
                      child: const Text('关闭'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('关闭'));
          await tester.pumpAndSettle();
          expect(find.text(busy ? '$task进行中' : '关闭窗口'), findsOneWidget);
          expect(find.text('记住我的选择'), busy ? findsNothing : findsOneWidget);
          if (busy) {
            expect(find.textContaining('可继续$task'), findsOneWidget);
            expect(
              find.text(task == '值守' ? '退出并停止检测' : '退出并停止值守'),
              findsNothing,
            );
          }
          if (busy && Platform.environment['CAPTURE_CLOSE_DIALOG'] == '1') {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('close-capture')),
              );
              final image = await boundary.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('build/close-dialog').create(recursive: true);
              await File(
                'build/close-dialog/${task == '值守' ? 'watch' : 'detection'}.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.tap(find.text(busy ? '退出并停止$task' : '退出应用'));
          await tester.pumpAndSettle();
          expect(result!.action, CloseAskAction.quit);
          expect(result!.remember, !busy);
          await tester.tap(find.text('关闭'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('最小化到托盘'));
          await tester.pumpAndSettle();
          expect(result!.action, CloseAskAction.tray);
          expect(result!.remember, !busy);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
