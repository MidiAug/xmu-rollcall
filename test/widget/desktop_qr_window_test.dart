import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xmu_rollcall/features/rollcall/desktop_qr_window.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';

import '../unit/desktop_qr_decoder_test.dart' as fixture;
import '../fixtures/desktop_ui_capture.dart';

const _windows = MethodChannel('mixin.one/desktop_multi_window');
const _channels = MethodChannel('mixin.one/desktop_multi_window/channels');
const _capture = MethodChannel('xmu_rollcall/desktop_capture');
const _codec = StandardMethodCodec();

Future<void> _fromOwner(String method, [Map<String, Object?>? args]) {
  final done = Completer<void>();
  ServicesBinding.instance.channelBuffers.push(
    _channels.name,
    _codec.encodeMethodCall(
      MethodCall('methodCall', {
        'channel': 'mixin.one/window_controller/scanner',
        'method': method,
        'arguments': args,
      }),
    ),
    (_) => done.complete(),
  );
  return done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesktopUiCaptureFonts);
  final nativeCalls = <String>[];
  final events = <Map>[];
  Completer<void>? nextEvent;
  var captureFails = false;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    nativeCalls.clear();
    events.clear();
    nextEvent = null;
    captureFails = false;
    messenger.setMockMethodCallHandler(
      _windows,
      (call) async => {'windowId': 'scanner', 'windowArgument': ''},
    );
    messenger.setMockMethodCallHandler(_channels, (call) async {
      if (call.method == 'invokeMethod') {
        final event = Map.of(call.arguments as Map);
        events.add(event);
        if (nextEvent?.isCompleted == false) nextEvent!.complete();
      }
      return null;
    });
    messenger.setMockMethodCallHandler(_capture, (call) async {
      nativeCalls.add(call.method);
      if (call.method == 'capture' && captureFails) {
        throw PlatformException(code: 'capture_failed');
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(_windows, null);
    messenger.setMockMethodCallHandler(_channels, null);
    messenger.setMockMethodCallHandler(_capture, null);
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(420, 548),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('desktop-ui-capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: desktopCaptureTheme(AppTheme.dark()),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          color: Colors.transparent,
          home: DesktopQrScanWindow(
            controller: WindowController.fromWindowId('scanner'),
            owner: WindowController.fromWindowId('owner'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(events.last['method'], 'qr_ready');
  }

  Future<void> start(
    WidgetTester tester, {
    int session = 1,
    String course = '501',
  }) async {
    final pending = _fromOwner('scan_start', {
      'sessionId': session,
      'rollcallId': 9001,
      'courseId': course,
    });
    var completed = false;
    pending.then((_) => completed = true);
    for (var i = 0; i < 10 && !completed; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(completed, isTrue, reason: 'scan_start must finish after rendering');
    await pending;
  }

  Future<void> closeScenario(WidgetTester tester) async {
    await mount(tester);
    await start(tester);
    expect(nativeCalls, contains('show'));
    await tester.tap(find.byTooltip('关闭扫码窗'));
    await tester.pump();
    await _fromOwner('scan_cancel');
    await tester.pump(const Duration(seconds: 2));
    expect(nativeCalls.where((c) => c == 'hide'), hasLength(1));
    expect(nativeCalls, isNot(contains('capture')));
    final results = events.where((e) => e['method'] == 'qr_complete');
    expect(results, hasLength(1));
    expect(results.single['arguments'], {'sessionId': 1, 'raw': null});
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> pauseScenario(WidgetTester tester) async {
    await mount(tester);
    await start(tester);
    await tester.tap(find.text('暂停识别'));
    await tester.pump(const Duration(seconds: 2));
    expect(nativeCalls, isNot(contains('capture')));
    captureFails = true;
    await tester.tap(find.text('继续识别'));
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(find.text('屏幕读取暂不可用，仍可拖入或选择图片'), findsOneWidget);
    final failures = events.where(
      (e) =>
          e['method'] == 'qr_log' &&
          (e['arguments'] as Map)['event'] == 'qr.desktop.capture_error',
    );
    expect(failures, hasLength(1));
    await _fromOwner('scan_cancel');
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> dropScenario(WidgetTester tester) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('xmu_qr_window_'),
    ))!;
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/sample.png');
    await tester.runAsync(
      () => file.writeAsBytes(img.encodePng(fixture.sample())),
    );
    await mount(tester);
    await start(tester, course: '999');

    Future<void> drop() async {
      await tester.runAsync(() async {
        nextEvent = Completer<void>();
        tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
          DropDoneDetails(
            files: [DropItemFile(file.path)],
            localPosition: Offset.zero,
            globalPosition: Offset.zero,
          ),
        );
        await nextEvent!.future.timeout(const Duration(seconds: 10));
      });
      await tester.pump();
    }

    await drop();
    expect(find.text('这个二维码不属于本次签到，请重新选择'), findsOneWidget);
    expect(events.where((e) => e['method'] == 'qr_complete'), isEmpty);
    await _fromOwner('scan_cancel');
    await start(tester, session: 2);
    await drop();
    // The detected log precedes completion; flush its continuation too.
    await tester.pump();
    expect(find.text('已识别'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 220));
    await captureDesktopUi(tester, 'scanner-recognized');
    expect(
      events.where(
        (e) =>
            e['method'] == 'qr_complete' &&
            (e['arguments'] as Map)['sessionId'] == 2,
      ),
      isEmpty,
    );
    await tester.pump(const Duration(milliseconds: 479));
    expect(nativeCalls.last, isNot('hide'));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    final result = events.lastWhere((e) => e['method'] == 'qr_complete');
    expect((result['arguments'] as Map)['sessionId'], 2);
    expect(
      (result['arguments'] as Map)['raw'],
      contains('DEVELOPMENT_PREVIEW_ONLY'),
    );
    await start(tester, session: 3);
    await drop();
    expect(find.text('已识别'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭扫码窗'));
    await tester.pump(const Duration(seconds: 1));
    final cancelled = events.where(
      (e) =>
          e['method'] == 'qr_complete' &&
          (e['arguments'] as Map)['sessionId'] == 3,
    );
    expect(cancelled, hasLength(1));
    expect((cancelled.single['arguments'] as Map)['raw'], isNull);
    await start(tester, session: 4);
    expect(find.text('已识别'), findsNothing);
    await _fromOwner('scan_cancel');
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> compactScenario(WidgetTester tester) async {
    await mount(tester, size: const Size(340, 420), textScale: 1.3);
    await start(tester);
    for (final label in ['选择图片', '暂停识别']) {
      final text = find.text(label);
      final button = find.ancestor(
        of: text,
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(
        tester.getRect(button).contains(tester.getRect(text).topLeft),
        isTrue,
      );
      expect(
        tester.getRect(button).contains(tester.getRect(text).bottomRight),
        isTrue,
      );
    }
    await captureDesktopUi(tester, 'scanner-compact-large-text');
    await _fromOwner('scan_cancel');
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> dragScenario(WidgetTester tester) async {
    await mount(tester);
    await start(tester);
    await captureDesktopUi(tester, 'scanner-ready');
    await tester.dragFrom(const Offset(180, 40), const Offset(65, 25));
    await tester.pump();
    expect(nativeCalls.where((c) => c == 'startDrag'), hasLength(1));
    expect(nativeCalls, isNot(contains('move')));
    final done = Completer<void>();
    ServicesBinding.instance.channelBuffers.push(
      _capture.name,
      _codec.encodeMethodCall(const MethodCall('interactionChanged', true)),
      (_) => done.complete(),
    );
    await done.future;
    nativeCalls.clear();
    await tester.pump(const Duration(seconds: 2));
    expect(nativeCalls, isNot(contains('capture')));
    await _fromOwner('scan_cancel');
    await tester.pumpWidget(const SizedBox());
  }

  // The plugin keeps its channel registration for the engine lifetime. Exercise
  // repeated window mounts in one engine, rather than resetting its messenger.
  testWidgets(
    'scanner closes, pauses, recovers and validates dropped courses',
    (tester) async {
      await mount(tester);
      final opening = _fromOwner('scan_start', {
        'sessionId': 99,
        'rollcallId': 9001,
        'courseId': '501',
      });
      await _fromOwner('scan_cancel');
      await tester.pump();
      await tester.pump();
      await opening;
      expect(
        nativeCalls,
        isNot(contains('show')),
        reason: 'cancel before first paint must not show a late window',
      );
      await tester.pumpWidget(const SizedBox());
      nativeCalls.clear();
      events.clear();
      await closeScenario(tester);
      nativeCalls.clear();
      events.clear();
      await dragScenario(tester);
      nativeCalls.clear();
      events.clear();
      await pauseScenario(tester);
      nativeCalls.clear();
      events.clear();
      captureFails = false;
      await dropScenario(tester);
      nativeCalls.clear();
      events.clear();
      await compactScenario(tester);
    },
  );
}
