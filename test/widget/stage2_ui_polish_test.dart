import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_switch.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import '../fixtures/preview_fonts.dart';

class _Stage2ShadowBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  if (Platform.environment['CAPTURE_STAGE2_UI'] == '1') {
    _Stage2ShadowBinding();
  }
  setUpAll(loadDesktopPreviewFonts);
  tearDown(AppToast.dismiss);

  for (final dark in [false, true]) {
    testWidgets(
      'stage-2 switch, segmented, active icon, dialog and menu contracts dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(960, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final p = dark ? AppPalette.darkPalette : AppPalette.lightPalette;
        var selectValue = 0;
        var compactChoice = 0;
        var normalChoice = 1;

        await tester.pumpWidget(
          MaterialApp(
            theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppSwitch(value: false, onChanged: (_) {}),
                        const SizedBox(width: 12),
                        AppSwitch(value: true, onChanged: (_) {}),
                        const SizedBox(width: 16),
                        AppIconButton(
                          tooltip: '打开菜单',
                          active: true,
                          icon: const Icon(AppIcons.more),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StatefulBuilder(
                      builder: (context, setState) => AppSegmentedControl<int>(
                        compact: true,
                        segments: const [
                          AppSegment(value: 0, label: '浅色'),
                          AppSegment(value: 1, label: '暗色'),
                        ],
                        value: compactChoice,
                        onChanged: (v) => setState(() => compactChoice = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StatefulBuilder(
                      builder: (context, setState) => AppSegmentedControl<int>(
                        compact: false,
                        segments: const [
                          AppSegment(value: 0, label: '全部'),
                          AppSegment(value: 1, label: '未提交'),
                        ],
                        value: normalChoice,
                        onChanged: (v) => setState(() => normalChoice = v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    StatefulBuilder(
                      builder: (context, setState) => AppShellSelect<int>(
                        value: selectValue,
                        items: const [0, 1, 2],
                        labelOf: (v) => '线路 $v',
                        onChanged: (v) => setState(() => selectValue = v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(
                      width: 280,
                      child: AppDialogFrame(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('弹窗层级'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Both off and on AppSwitch thumbs are pure white with soft shadow.
        final thumbs = tester
            .widgetList<Container>(
              find.byKey(const ValueKey('app-switch-thumb')),
            )
            .toList();
        expect(thumbs, hasLength(2));
        for (final thumb in thumbs) {
          final decoration = thumb.decoration! as BoxDecoration;
          expect(decoration.color, Colors.white);
          expect(decoration.boxShadow, isNotEmpty);
        }

        // 2. Active AppIconButton uses neutral pressed fill, not blue selected.
        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        final activeBg = iconButton.style!.backgroundColor!.resolve({});
        expect(activeBg, p.controlPressed);
        expect(activeBg, isNot(p.selected));

        // 3. Compact & normal SegmentedControl use ink text and shadowed concentric thumbs.
        final thumbMarkers = find
            .byKey(const ValueKey('segment-selection'))
            .evaluate()
            .toList();
        expect(thumbMarkers, hasLength(2));
        final compactThumbBox = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byKey(const ValueKey('segment-selection')).first,
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final compactDecoration = compactThumbBox.decoration as BoxDecoration;
        expect(compactDecoration.boxShadow, isNotNull);
        expect(compactDecoration.boxShadow, isNotEmpty);
        expect(
          compactDecoration.borderRadius,
          BorderRadius.circular(AppRadii.segmentThumb),
        );
        final normalThumbBox = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byKey(const ValueKey('segment-selection')).last,
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final normalDecoration = normalThumbBox.decoration as BoxDecoration;
        expect(
          normalDecoration.borderRadius,
          BorderRadius.circular(AppRadii.segmentThumb),
        );
        expect(tester.widget<Text>(find.text('未提交')).style!.color, p.ink);

        // 4. AppDialogFrame uses solid elevated popoverSurface without gradient.
        final dialogDecoration = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(AppDialogFrame),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((w) => w.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.color != null);
        expect(dialogDecoration.color, p.popoverSurface);
        expect(dialogDecoration.gradient, isNull);

        // 5. Single-cursor dropdown menu: idle selected item has transparent fill
        //    plus check mark; hovering unselected highlights only unselected;
        //    hovering selected highlights selected.
        await tester.tap(find.byType(AppSelectTrigger));
        await tester.pumpAndSettle();
        BoxDecoration optionFill(int index) {
          final container = tester.widget<AnimatedContainer>(
            find.descendant(
              of: find.byKey(ValueKey('shell-select-option-$index')),
              matching: find.byType(AnimatedContainer),
            ),
          );
          return container.decoration! as BoxDecoration;
        }

        expect(optionFill(0).color!.a, 0);
        expect(
          tester
              .widget<Icon>(
                find.descendant(
                  of: find.byKey(const ValueKey('shell-select-option-0')),
                  matching: find.byIcon(AppIcons.check),
                ),
              )
              .color,
          p.primary,
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(
          tester.getCenter(find.byKey(const ValueKey('shell-select-option-1'))),
        );
        await tester.pumpAndSettle();
        expect(optionFill(0).color!.a, 0);
        expect(optionFill(1).color, p.hover);

        await mouse.moveTo(
          tester.getCenter(find.byKey(const ValueKey('shell-select-option-0'))),
        );
        await tester.pumpAndSettle();
        expect(optionFill(0).color, p.hover);
        expect(optionFill(1).color!.a, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets('AppToast fades smoothly and honors disableAnimations', (
    tester,
  ) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    AppToast.show(
      hostContext,
      '已保存设置',
      duration: const Duration(milliseconds: 500),
    );
    await tester.pump();
    final transition = find.descendant(
      of: find.byType(Overlay),
      matching: find.byType(FadeTransition),
    );
    expect(transition, findsWidgets);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('已保存设置'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('已保存设置'), findsNothing);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                hostContext = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    AppToast.show(
      hostContext,
      '即时提示',
      duration: const Duration(milliseconds: 500),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('即时提示'), findsOneWidget);
    AppToast.dismiss();
    await tester.pump();
    expect(find.text('即时提示'), findsNothing);
  });

  if (Platform.environment['CAPTURE_STAGE2_UI'] == '1') {
    for (final dark in [false, true]) {
      testWidgets('capture stage-2 showcase dark=$dark', (tester) async {
        tester.view.physicalSize = const Size(1120, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        final p = dark ? AppPalette.darkPalette : AppPalette.lightPalette;
        final focusController = TextEditingController(text: '搜索关键字');
        addTearDown(focusController.dispose);
        final searchFocus = FocusNode();
        addTearDown(searchFocus.dispose);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
              platform: TargetPlatform.windows,
            ),
            builder: (context, child) =>
                RepaintBoundary(key: capture, child: child!),
            home: Scaffold(
              backgroundColor: p.canvas,
              body: Row(
                children: [
                  AppSidebar(
                    current: AppDestination.rollcall,
                    onSelect: (_) {},
                    userLabel: '主账号同学',
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AppSegmentedControl<int>(
                                segments: const [
                                  AppSegment(value: 0, label: '全部'),
                                  AppSegment(value: 1, label: '进行中'),
                                  AppSegment(value: 2, label: '已结束'),
                                ],
                                value: 0,
                                onChanged: (_) {},
                              ),
                              const Spacer(),
                              AppButton(
                                compact: true,
                                label: '次要动作',
                                kind: AppButtonKind.secondary,
                                onPressed: () {},
                              ),
                              const SizedBox(width: 8),
                              AppButton(
                                compact: true,
                                label: '主要提交',
                                onPressed: () {},
                              ),
                              const SizedBox(width: 8),
                              AppIconButton(
                                tooltip: '更多操作',
                                extent: 36,
                                active: true,
                                icon: const Icon(AppIcons.more),
                                onPressed: () {},
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SettingsSection(
                            header: '核心控件对照',
                            children: [
                              SettingsRow(
                                title: '界面主题',
                                leading: const Icon(AppIcons.theme),
                                trailing: AppSegmentedControl<int>(
                                  compact: true,
                                  segments: const [
                                    AppSegment(value: 0, label: '浅色'),
                                    AppSegment(value: 1, label: '暗色'),
                                    AppSegment(value: 2, label: '跟随系统'),
                                  ],
                                  value: dark ? 1 : 0,
                                  onChanged: (_) {},
                                ),
                              ),
                              SettingsRow(
                                title: '关闭窗口时',
                                leading: const Icon(AppIcons.settings),
                                trailing: SizedBox(
                                  width: 156,
                                  child: AppShellSelect<int>(
                                    key: const ValueKey('showcase-select'),
                                    plain: true,
                                    compact: true,
                                    width: 156,
                                    menuWidth: 200,
                                    value: 0,
                                    items: const [0, 1, 2],
                                    labelOf: (v) =>
                                        ['最小化到托盘', '直接退出', '每次询问'][v],
                                    onChanged: (_) {},
                                  ),
                                ),
                              ),
                              SettingsRow(
                                title: '开关关闭态与开启态',
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppSwitch(value: false, onChanged: (_) {}),
                                    const SizedBox(width: 8),
                                    AppSwitch(value: true, onChanged: (_) {}),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 280,
                                child: TextField(
                                  focusNode: searchFocus,
                                  controller: focusController,
                                  decoration: const InputDecoration(
                                    hintText: '聚焦输入框光环预览',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    AppStatusBadge(
                                      '已签',
                                      tone: AppStatusTone.success,
                                    ),
                                    AppStatusBadge(
                                      '待定',
                                      tone: AppStatusTone.warning,
                                    ),
                                    AppStatusBadge(
                                      '缺失',
                                      tone: AppStatusTone.danger,
                                    ),
                                    AppStatusBadge('草稿'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 340,
                            child: AppDialogFrame(
                              insetPadding: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Builder(
                                  builder: (context) => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '弹窗与菜单浮层层次',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '浅色保持纯净白卡，深色抬高一层表面。',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        searchFocus.requestFocus();
        await tester.pumpAndSettle();
        AppToast.show(
          tester.element(find.byType(Scaffold)),
          '已保存设置',
          duration: const Duration(seconds: 5),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));

        // Capture idle + focused input + toast, plus open menu hover state.
        await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = await Directory(
            'build/stage2-ui-review',
          ).create(recursive: true);
          await File(
            '${dir.path}/showcase-idle-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });

        AppToast.dismiss();
        await tester.tap(find.byKey(const ValueKey('showcase-select')));
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(
          tester.getCenter(find.byKey(const ValueKey('shell-select-option-1'))),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/stage2-ui-review/showcase-menu-${dark ? 'dark' : 'light'}.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
