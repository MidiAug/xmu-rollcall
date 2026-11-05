import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/location/campus_story_dialog.dart';
import 'package:xmu_rollcall/features/location/teaching_catalog.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

class _PhotoClient extends Fake implements HttpClient {
  _PhotoClient(this.bytes, {this.fail = false});
  final Uint8List bytes;
  final bool fail;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _PhotoRequest(bytes, fail);
}

class _PhotoRequest extends Fake implements HttpClientRequest {
  _PhotoRequest(this.bytes, this.fail);
  final Uint8List bytes;
  final bool fail;
  @override
  Future<HttpClientResponse> close() async => _PhotoResponse(bytes, fail);
}

class _PhotoResponse extends Fake implements HttpClientResponse {
  _PhotoResponse(this.bytes, this.fail);
  final Uint8List bytes;
  final bool fail;
  @override
  int get statusCode => fail ? 404 : 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

void main() {
  initializeDesktopUiCapture();
  late Uint8List bytes;
  setUpAll(() async {
    await loadDesktopPreviewFonts();
    await loadDesktopUiCaptureFonts();
    final local = File('build/photo-review-xa-pool.jpg');
    if (Platform.environment['CAPTURE_DESKTOP_UI'] == '1' &&
        local.existsSync()) {
      bytes = await local.readAsBytes();
    } else {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(const Color(0xFFAAC2DA), BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(4, 4);
      bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
    }
  });
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    debugNetworkImageHttpClientProvider = () => _PhotoClient(bytes);
  });
  tearDown(() => debugNetworkImageHttpClientProvider = null);
  Future<void> open(
    WidgetTester tester, {
    required double width,
    required bool dark,
    String id = 'xa-pool',
    double scale = 1,
    bool highContrast = false,
  }) async {
    tester.view.physicalSize = Size(width, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              highContrast: highContrast,
            ),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CampusStoryDialog(
                  building: teachingBuildings.singleWhere((b) => b.id == id),
                ),
              ),
              child: const Text('阅读建筑'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('阅读建筑'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });
    await tester.pumpAndSettle();
    debugNetworkImageHttpClientProvider = null;
  }

  for (final width in [360.0, 1000.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'building profile uses actual photo and readable encyclopedia hierarchy $width dark=$dark',
        (tester) async {
          await open(
            tester,
            width: width,
            dark: dark,
            scale: width == 360 ? 1.3 : 1,
          );
          expect(
            find.byKey(const ValueKey('atlas-story-title')),
            findsOneWidget,
          );
          expect(find.byType(Image), findsNWidgets(2));
          expect(find.byType(ShaderMask), findsOneWidget);
          expect(find.text('楼宇'), findsNothing);
          expect(find.text('资料说明'), findsNothing);
          expect(find.text('当前分区'), findsNothing);
          expect(find.textContaining('不应混作'), findsNothing);
          expect(find.textContaining('图片来源'), findsNothing);
          expect(find.byType(SelectableText), findsNothing);
          await captureDesktopUi(tester, 'building-profile-$width-$dark');
          await tester.drag(
            find.byKey(const ValueKey('atlas-story-scroll')),
            const Offset(0, -550),
          );
          await tester.pumpAndSettle();
          expect(find.text('参考资料'), findsOneWidget);
          await tester.tap(find.text('参考资料'));
          await tester.pumpAndSettle();
          expect(find.byType(SelectableText), findsWidgets);
          await captureDesktopUi(tester, 'building-profile-body-$width-$dark');
          await tester.tap(find.byTooltip('关闭介绍'));
          await tester.pumpAndSettle();
          expect(find.byType(CampusStoryDialog), findsNothing);
        },
      );
    }
  }
  testWidgets('missing and failed photos keep usable reading and closing', (
    tester,
  ) async {
    debugNetworkImageHttpClientProvider = () => _PhotoClient(bytes, fail: true);
    await open(tester, width: 360, dark: false);
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const ValueKey('atlas-story-title')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureDesktopUi(tester, 'building-profile-photo-failure');
    await tester.tap(find.byTooltip('关闭介绍'));
    await tester.pumpAndSettle();
    await open(tester, width: 360, dark: true, id: 'sm-archives', scale: 1.5);
    expect(find.byKey(const ValueKey('atlas-story-title')), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('资料状态'), findsNothing);
    await captureDesktopUi(tester, 'building-profile-no-photo');
    expect(tester.takeException(), isNull);
  });
  testWidgets('high contrast keeps image and disables decorative blur', (
    tester,
  ) async {
    await open(tester, width: 1000, dark: false, highContrast: true);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(SelectableText), findsNothing);
    await tester.ensureVisible(find.text('参考资料'));
    Focus.of(tester.element(find.text('参考资料'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
