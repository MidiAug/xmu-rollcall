import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
  });
  for (final dark in [false, true]) {
    testWidgets(
      'action surfaces stay visible on the canvas when hovered dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(880, 580);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        final p = dark ? AppPalette.darkPalette : AppPalette.lightPalette;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: desktopCaptureTheme(
              (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                platform: TargetPlatform.windows,
              ),
            ),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('desktop-ui-capture'),
              child: child!,
            ),
            home: Scaffold(
              body: RepaintBoundary(
                key: boundary,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '共享控件状态检查',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          AppQuietPill(
                            key: const ValueKey('pause'),
                            background: p.surface,
                            radius: 10,
                            onTap: () {},
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  AppIcons.guardPaused,
                                  size: 16,
                                  color: p.primary,
                                ),
                                const SizedBox(width: 6),
                                const Text('暂停值守'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppRefreshButton(
                            key: const ValueKey('refresh'),
                            onRefresh: () async {},
                          ),
                          const SizedBox(width: 8),
                          AppIconButton(
                            key: const ValueKey('history'),
                            framed: true,
                            extent: 34,
                            tooltip: '查看记录',
                            icon: const Icon(AppIcons.history),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 8),
                          AppIconButton(
                            key: const ValueKey('settings'),
                            framed: true,
                            extent: 34,
                            tooltip: '检测设置',
                            icon: const Icon(AppIcons.settings),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          const SizedBox(
                            width: 260,
                            child: AppSearchField(
                              compact: true,
                              hintText: '搜索姓名或学号',
                            ),
                          ),
                          const SizedBox(width: 12),
                          AppShellSelect<int>(
                            key: const ValueKey('select'),
                            compact: true,
                            value: 0,
                            items: const [0, 1],
                            labelOf: (v) => v == 0 ? '全部学生' : '已提交',
                            onChanged: (_) {},
                          ),
                          const SizedBox(width: 12),
                          AppButton(
                            compact: true,
                            label: '导入成绩',
                            icon: AppIcons.upload,
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 12,
                        children: [
                          AppButton(label: '保存设置', onPressed: () {}),
                          AppButton(
                            key: const ValueKey('secondary'),
                            kind: AppButtonKind.secondary,
                            label: '取消',
                            onPressed: () {},
                          ),
                          AppButton(
                            key: const ValueKey('quiet'),
                            kind: AppButtonKind.quiet,
                            label: '选择已提交学生',
                            onPressed: () {},
                          ),
                          const AppButton(label: '暂不可用', onPressed: null),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          SizedBox(
                            width: 260,
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: '分数',
                                errorText: '请输入0–100之间的分数',
                              ),
                            ),
                          ),
                          const SizedBox(width: 32),
                          AppQuietPill(
                            key: const ValueKey('strong'),
                            background: p.primary,
                            onTap: () {},
                            child: Text(
                              '确认提交',
                              style: TextStyle(
                                color: dark ? p.canvas : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await captureDesktopUi(tester, 'controls-idle-$dark');
        final mouse = await tester.createGesture(
          kind: ui.PointerDeviceKind.mouse,
        );
        await mouse.addPointer(location: const Offset(850, 550));
        addTearDown(mouse.removePointer);
        for (final name in [
          'pause',
          'refresh',
          'history',
          'settings',
          'secondary',
          'quiet',
          'select',
        ]) {
          final target = find.byKey(ValueKey(name));
          final rect = tester.getRect(target);
          await mouse.moveTo(rect.center);
          await tester.pumpAndSettle();
          expect(tester.getRect(target), rect);
          final color = await tester.runAsync(() async {
            final im =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await im.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final bytes = data!.buffer.asUint8List();
            final i =
                (rect.center.dy.floor() * im.width + rect.left.floor() + 6) * 4;
            final color = Color.fromARGB(
              bytes[i + 3],
              bytes[i],
              bytes[i + 1],
              bytes[i + 2],
            );
            im.dispose();
            return color;
          });
          expect(
            color!.computeLuminance(),
            greaterThan(p.canvas.computeLuminance() + .02),
            reason: '$name hover must remain a visible action surface',
          );
          await captureDesktopUi(tester, 'controls-hover-$name-$dark');
        }
        await mouse.moveTo(
          tester.getCenter(find.byKey(const ValueKey('strong'))),
        );
        await tester.pumpAndSettle();
        await captureDesktopUi(tester, 'controls-hover-strong-$dark');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
