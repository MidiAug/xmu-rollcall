import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';
import 'package:xmu_rollcall/features/rollcall/qr_scan_camera_page.dart';
import 'package:xmu_rollcall/features/rollcall/qr_scan_frame.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

// Only the native camera boundary is substituted; the page and controller run.
class _Camera extends MobileScannerPlatform {
  bool denied = false;
  int torchCalls = 0;
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const SizedBox.expand();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    if (denied) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
      numberOfCameras: 1,
    );
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> toggleTorch() async {
    torchCalls++;
  }
}

void main() {
  initializeDesktopUiCapture();
  setUpAll(loadDesktopPreviewFonts);
  late MobileScannerPlatform previous;
  late _Camera camera;
  setUp(() {
    previous = MobileScannerPlatform.instance;
    camera = _Camera();
    MobileScannerPlatform.instance = camera;
  });
  tearDown(() => MobileScannerPlatform.instance = previous);

  Future<void> show(
    WidgetTester tester, {
    required bool dark,
    double scale = 1,
    double width = 390,
  }) async {
    tester.view.physicalSize = Size(width, width == 320 ? 568 : 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('desktop-ui-capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
            platform: TargetPlatform.android,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const QrScanCameraPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    for (final width in [320.0, 390.0]) {
      testWidgets('camera framing, torch and short window $width dark=$dark', (
        tester,
      ) async {
        await show(
          tester,
          dark: dark,
          width: width,
          scale: width == 320 ? 2 : 1,
        );
        expect(find.byType(QrScanFrame), findsOneWidget);
        final torch = find.widgetWithText(OutlinedButton, '开关补光灯');
        expect(
          tester.getRect(find.byType(QrScanFrame)).bottom,
          lessThan(tester.getRect(torch).top),
        );
        await tester.tap(torch);
        await tester.pumpAndSettle();
        expect(camera.torchCalls, 1);
        final p = AppPalette.of(tester.element(torch));
        final contrast =
            (p.scannerInk.computeLuminance() + .05) /
            (p.scannerControl.computeLuminance() + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        await captureDesktopUi(tester, 'camera-r25-${width.toInt()}-$dark');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }

  testWidgets('permission recovery hides capture overlay until camera starts', (
    tester,
  ) async {
    camera.denied = true;
    await show(tester, dark: false);
    expect(find.textContaining('未获得相机权限'), findsOneWidget);
    expect(find.byType(QrScanFrame), findsNothing);
    expect(find.text('开关补光灯'), findsNothing);
    camera.denied = false;
    await tester.tap(find.text('重试相机'));
    await tester.pumpAndSettle();
    expect(find.byType(QrScanFrame), findsOneWidget);
    expect(find.textContaining('未获得相机权限'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
