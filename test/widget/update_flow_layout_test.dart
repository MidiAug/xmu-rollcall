import 'dart:async';
import 'dart:io';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/update/app_release.dart';
import 'package:xmu_rollcall/features/update/app_update_section.dart';
import '../fixtures/update_fakes.dart';

void main() {
  setUpAll(() async {
    final font = Platform.environment['ABOUT_UI_FONT'];
    if (font != null) {
      await (FontLoader(
        'UpdatePreview',
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
    testWidgets(
      'update flow remains compact and switching route safely restarts at $width',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = FakeUpdateService()
          ..result = ReleaseUpdate(
            version: const AppVersion(0, 2, 0, 3),
            target: width < 600 ? UpdateTarget.android : UpdateTarget.windows,
            notes:
                '## 修复\n\n- **签到码**在重启后恢复。\n- 改进更新检查与下载。\n\n### 安装\n\n下载后需要确认安装。',
            size: 11 * 1024 * 1024,
            sha256: '0' * 64,
          );
        final installer = FakeUpdateInstaller();
        final key = GlobalKey();
        var theme = width == 384 ? AppTheme.dark() : AppTheme.light();
        if (Platform.environment['ABOUT_UI_FONT'] != null) {
          theme = theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'UpdatePreview'),
            filledButtonTheme: const FilledButtonThemeData(
              style: ButtonStyle(
                textStyle: WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'UpdatePreview', fontSize: 13),
                ),
              ),
            ),
            textButtonTheme: const TextButtonThemeData(
              style: ButtonStyle(
                textStyle: WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'UpdatePreview', fontSize: 13),
                ),
              ),
            ),
          );
        }
        Future<void> capture(String name) async {
          expect(tester.takeException(), isNull);
          AppToast.dismiss();
          if (Platform.environment['CAPTURE_UPDATE_FLOW'] != '1') return;
          await tester.runAsync(() async {
            final dir = await Directory(
              '.tools/update-check-incident/previews',
            ).create(recursive: true);
            final img =
                await (key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await img.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '${dir.path}/${width.toInt()}-$name.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            img.dispose();
          });
        }

        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 1.3 : 1),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 552,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView(
                        children: [
                          AppUpdateSection(
                            package: Future.value(
                              PackageInfo(
                                appName: 'test',
                                packageName: 'cn.edu.xmu.rollcall.xmu_rollcall',
                                version: '0.1.3',
                                buildNumber: '4',
                              ),
                            ),
                            target: width < 600
                                ? UpdateTarget.android
                                : UpdateTarget.windows,
                            service: service,
                            installer: installer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture('01-available');
        await tester.tap(find.text('有更新 · v0.2.0'));
        await tester.pumpAndSettle();
        expect(find.text('下载线路'), findsNothing);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('update-route-select')))
              .width,
          lessThanOrEqualTo(180),
        );
        final routeRect = tester.getRect(
          find.byKey(const ValueKey('update-route-select')),
        );
        final dialogSurface = find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first;
        final dialogRect = tester.getRect(dialogSurface);
        expect(routeRect.right, closeTo(dialogRect.right - 20, 1));
        expect(tester.getCenter(find.text('关闭')).dx, lessThan(routeRect.left));
        await capture('02-notes');
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
        service.pendingDownload = Completer<File>();
        await tester.tap(find.byTooltip('下载更新'));
        await tester.pumpAndSettle();
        final oldCancel = service.downloadCancel!;
        await capture('03-downloading');
        await tester.tap(find.text('正在下载 50%'));
        await tester.pumpAndSettle();
        expect(find.text('发布页'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('update-route-select')));
        await tester.pumpAndSettle();
        await capture('04-routes');
        await tester.tap(find.text('gh-proxy.com').last);
        await tester.pumpAndSettle();
        expect(find.text('更新说明'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
        expect(oldCancel.isCancelled, isTrue);
        expect(service.downloads, 2);
        expect(service.downloadCancel!.isCancelled, isFalse);
        service.pendingDownload!.complete(File('fixture'));
        await tester.pumpAndSettle();
        await capture('05-ready');
        await tester.tap(find.byTooltip(width < 600 ? '安装更新' : '退出并安装'));
        await tester.pumpAndSettle();
        await capture('06-confirmation');
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(installer.calls, 0);
        expect(tester.takeException(), isNull);
        AppToast.dismiss();
      },
    );
  }
}
