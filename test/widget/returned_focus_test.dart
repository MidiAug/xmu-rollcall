import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_service_tile.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });
  for (final dark in [false, true]) {
    for (final modal in [false, true]) {
      for (final kind in [
        'service',
        'surface',
        'settings',
        'select',
        'menu',
        'segment',
        'icon',
        'button',
      ]) {
        testWidgets(
          'pointer return restores idle and Tab retains focus $kind modal=$modal dark=$dark',
          (tester) async {
            final navigator = GlobalKey<NavigatorState>();
            final capture = GlobalKey();
            final target = GlobalKey();
            final nextFocus = FocusNode();
            addTearDown(nextFocus.dispose);
            void open() {
              final close = TextButton(
                key: const ValueKey('dismiss-child'),
                onPressed: () => navigator.currentState!.pop(),
                child: const Text('返回入口'),
              );
              if (modal) {
                showDialog<void>(
                  context: navigator.currentContext!,
                  builder: (_) => AlertDialog(content: close),
                );
              } else {
                navigator.currentState!.push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(body: Center(child: close)),
                  ),
                );
              }
            }

            final Widget control = switch (kind) {
              'service' => AppServiceTile(
                title: '修改作业',
                description: '作业打包下载与批量评分',
                icon: AppIcons.serviceGrading,
                onPressed: open,
              ),
              'surface' => AppHoverSurface(
                onTap: open,
                padding: const EdgeInsets.all(20),
                child: const Text('课程作业'),
              ),
              'settings' => SettingsRow(title: '设置入口', onTap: open),
              'select' => AppSelectTrigger(label: '选择课程', onTap: open),
              'menu' => AppMenuOption(
                label: '当前课程',
                selected: true,
                onTap: open,
              ),
              'segment' => AppSegmentedControl<int>(
                value: 0,
                segments: const [
                  AppSegment(value: 0, label: '本周'),
                  AppSegment(value: 1, label: '学期'),
                ],
                onChanged: (_) => open(),
              ),
              'icon' => AppIconButton(
                tooltip: '打开页面',
                icon: const Icon(AppIcons.right),
                onPressed: open,
              ),
              _ => AppButton(label: '进入页面', onPressed: open),
            };
            await tester.pumpWidget(
              MaterialApp(
                navigatorKey: navigator,
                theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: TargetPlatform.windows,
                ),
                home: Scaffold(
                  body: Column(
                    children: [
                      RepaintBoundary(
                        key: capture,
                        child: SizedBox(
                          key: target,
                          width: 380,
                          child: control,
                        ),
                      ),
                      TextButton(
                        focusNode: nextFocus,
                        onPressed: () {},
                        child: const Text('下一个操作'),
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            // Compare the same loaded artwork before and after navigation,
            // rather than a first-frame placeholder with a decoded bitmap.
            for (final element in find.byType(Image).evaluate()) {
              final image = element.widget as Image;
              await tester.runAsync(() => precacheImage(image.image, element));
            }
            await tester.pumpAndSettle();
            Future<Uint8List> pixels() async =>
                (await tester.runAsync(() async {
                  final image =
                      await (capture.currentContext!.findRenderObject()!
                              as RenderRepaintBoundary)
                          .toImage();
                  try {
                    return (await image.toByteData(
                      format: ui.ImageByteFormat.rawRgba,
                    ))!.buffer.asUint8List();
                  } finally {
                    image.dispose();
                  }
                }))!;
            final idle = await pixels();
            final mouse = await tester.createGesture(
              kind: ui.PointerDeviceKind.mouse,
            );
            await mouse.addPointer(location: const Offset(700, 500));
            addTearDown(mouse.removePointer);
            final click = kind == 'segment'
                ? tester.getCenter(find.text('学期'))
                : tester.getCenter(find.byKey(target));
            await mouse.moveTo(click);
            await mouse.down(click);
            await tester.pump();
            await mouse.up();
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('dismiss-child')), findsOneWidget);
            final back = tester.getCenter(
              find.byKey(const ValueKey('dismiss-child')),
            );
            await mouse.moveTo(back);
            await mouse.down(back);
            await tester.pump();
            await mouse.up();
            await mouse.moveTo(const Offset(700, 500));
            await tester.pumpAndSettle();
            expect(
              listEquals(await pixels(), idle),
              isTrue,
              reason: 'pointer navigation must not restore a keyboard outline',
            );
            nextFocus.requestFocus();
            await tester.pumpAndSettle();
            await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
            await tester.pumpAndSettle();
            expect(
              listEquals(await pixels(), idle),
              isFalse,
              reason: 'Tab back to the entry must reveal keyboard focus',
            );
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.windows),
        );
      }
    }
  }
}
