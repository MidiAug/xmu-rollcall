import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/app/app_switch.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  setUpAll(loadDesktopPreviewFonts);
  testWidgets('composite settings disclosure keeps pointer feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light().copyWith(platform: TargetPlatform.windows),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 500,
              child: SettingsRow(
                title: '关于',
                onTap: () {},
                trailing: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('有更新'),
                    SizedBox(width: 8),
                    Icon(AppIcons.right),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byType(SettingsRow);
    final arrow = find.byIcon(AppIcons.right);
    final palette = AppPalette.of(tester.element(row));
    final geometry = tester.getRect(row);
    Color? ink() => tester
        .renderObject<RenderParagraph>(
          find.descendant(of: arrow, matching: find.byType(RichText)),
        )
        .text
        .style
        ?.color;
    expect(ink(), palette.muted);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(row));
    await tester.pumpAndSettle();
    expect(ink(), palette.ink);
    await mouse.down(tester.getCenter(row));
    await tester.pumpAndSettle();
    expect(ink(), palette.primary);
    await mouse.cancel();
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(ink(), palette.muted);
    expect(tester.getRect(row), geometry);
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
      testWidgets(
        'settings form grid and current-value alignment $dark $direction',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                platform: TargetPlatform.windows,
              ),
              home: Directionality(
                textDirection: direction,
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 600,
                      child: SettingsSection(
                        key: const ValueKey('section'),
                        padTop: false,
                        children: [
                          SettingsRow(
                            key: const ValueKey('single'),
                            leading: const Icon(AppIcons.externalLink),
                            title: '打开方式',
                            trailing: AppShellSelect<String>(
                              value: '本软件',
                              items: const ['本软件', '系统默认浏览器'],
                              labelOf: (v) => v,
                              onChanged: (_) {},
                              width: 148,
                              plain: true,
                              compact: true,
                              alignValueEnd: true,
                            ),
                          ),
                          const SettingsRow(
                            key: ValueKey('support'),
                            leading: Icon(AppIcons.guard),
                            title: '启动后继续值守',
                            subtitle: '恢复主账号登录后，自动按课表等待',
                            trailing: AppSwitch(value: false, onChanged: null),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final single = find.byKey(const ValueKey('single'));
          final support = find.byKey(const ValueKey('support'));
          expect(tester.getSize(single).height, 48);
          expect(tester.getSize(support).height, greaterThanOrEqualTo(60));
          final title = tester.getRect(find.text('打开方式'));
          final leading = tester.getRect(find.byIcon(AppIcons.externalLink));
          final titleInset = direction == TextDirection.ltr
              ? title.left - tester.getRect(single).left
              : tester.getRect(single).right - title.right;
          final iconGap = direction == TextDirection.ltr
              ? title.left - leading.right
              : leading.left - title.right;
          expect(iconGap, 12);
          expect(
            tester.widget<Divider>(find.byType(Divider)).indent,
            titleInset,
          );
          expect(
            tester.widget<Text>(find.text('打开方式')).style!.fontWeight,
            FontWeight.w500,
          );

          final value = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text('本软件'),
              matching: find.byType(RichText),
            ),
          );
          final box = value
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 3),
              )
              .single
              .toRect();
          final glyphs = box.shift(value.localToGlobal(Offset.zero));
          final arrow = tester.getRect(find.byIcon(AppIcons.down));
          final valueGap = direction == TextDirection.ltr
              ? arrow.left - glyphs.right
              : glyphs.left - arrow.right;
          expect(valueGap, inInclusiveRange(0, 10));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
