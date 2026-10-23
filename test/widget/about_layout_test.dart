import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/settings/about_page.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_controller.dart';
import '../fixtures/update_fakes.dart';

ThemeData _theme(bool dark) {
  final base = dark ? AppTheme.dark() : AppTheme.light();
  if (Platform.environment['ABOUT_UI_FONT'] == null) return base;
  ButtonStyle font(ButtonStyle? style) =>
      (style ?? const ButtonStyle()).copyWith(
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'AboutUi', fontSize: 13),
        ),
      );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'AboutUi'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'AboutUi'),
    filledButtonTheme: FilledButtonThemeData(
      style: font(base.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: font(base.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: font(base.textButtonTheme.style),
    ),
  );
}

void main() {
  setUpAll(() async {
    final font = Platform.environment['ABOUT_UI_FONT'];
    if (font != null) {
      await (FontLoader(
        'AboutUi',
      )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
      await (FontLoader('MaterialIcons')..addFont(
            File(
              Platform.environment['ABOUT_UI_ICONS']!,
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });
  for (final width in [320.0, 384.0, 960.0]) {
    for (final scenario in ['current', 'available', 'failed']) {
      testWidgets(
        'About $scenario fits width $width with large text and theme variations',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          PackageInfo.setMockInitialValues(
            appName: 'test',
            packageName: 'cn.edu.xmu.rollcall.xmu_rollcall',
            version: '0.1.1',
            buildNumber: '2',
            buildSignature: '',
          );
          final service = FakeUpdateService();
          if (scenario == 'available') {
            service.result = ReleaseUpdate(
              version: const AppVersion(0, 2, 0, 3),
              target: width < 600 ? UpdateTarget.android : UpdateTarget.windows,
              notes: '新增课程位置设置\n优化两端通知与更新体验',
              size: 76 * 1024 * 1024,
              sha256: '0' * 64,
            );
          }
          if (scenario == 'failed') {
            service.checkError = const UpdateException('更新服务暂不可用，请稍后重试。');
          }
          final controller = AppUpdateController(
            service: service,
            package: PackageInfo.fromPlatform,
            target: width < 600 ? UpdateTarget.android : UpdateTarget.windows,
          );
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: _theme(width == 384),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(width == 320 ? 1.3 : 1),
                  ),
                  child: child!,
                ),
                home: AboutPage(updateController: controller),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              scenario == 'current'
                  ? '已是最新版本'
                  : scenario == 'available'
                  ? '新版本 v0.2.0'
                  : '暂时无法检查',
            ),
            findsOneWidget,
          );
          expect(
            find.text('查看更新说明'),
            scenario == 'available' ? findsOneWidget : findsNothing,
          );
          expect(find.text('GitHub 发布页'), findsNothing);
          expect(tester.takeException(), isNull);
          if (Platform.environment['CAPTURE_ABOUT_UI'] == '1') {
            await tester.runAsync(() async {
              final image =
                  await (key.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '.tools/about-redesign/$scenario-${width.toInt()}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
        },
      );
    }
  }
}
