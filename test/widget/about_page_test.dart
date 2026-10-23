import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/settings/about_page.dart';
import '../fixtures/update_fakes.dart';

void main() {
  for (final width in [320.0, 384.0, 960.0]) {
    testWidgets('about version, repository and copy fit $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PackageInfo.setMockInitialValues(
        appName: '厦大签到',
        packageName: 'test',
        version: '0.1.0',
        buildNumber: '1',
        buildSignature: '',
      );
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: width == 960 ? AppTheme.dark() : AppTheme.light(),
          home: AboutPage(updateService: FakeUpdateService()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('版本 0.1.0'), findsOneWidget);
      expect(find.text('MidiAug/xmu-rollcall'), findsOneWidget);
      expect(find.textContaining('尚未创建'), findsNothing);
      await tester.ensureVisible(find.byTooltip('复制仓库地址'));
      await tester.tap(find.byTooltip('复制仓库地址'));
      await tester.pumpAndSettle();
      expect(copied, AboutPage.repository);
      expect(find.text('已复制仓库地址'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      AppToast.dismiss();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
