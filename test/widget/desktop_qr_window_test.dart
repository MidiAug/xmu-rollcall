import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xmu_rollcall/features/rollcall/desktop_qr_window.dart';

import '../unit/desktop_qr_decoder_test.dart' as fixture;

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

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 548);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      DesktopQrScanApp(
        controller: WindowController.fromWindowId('scanner'),
        owner: WindowController.fromWindowId('owner'),
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
    final result = events.lastWhere((e) => e['method'] == 'qr_complete');
    expect((result['arguments'] as Map)['sessionId'], 2);
    expect(
      (result['arguments'] as Map)['raw'],
      contains('DEVELOPMENT_PREVIEW_ONLY'),
    );
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
      await pauseScenario(tester);
      nativeCalls.clear();
      events.clear();
      captureFails = false;
      await dropScenario(tester);
    },
  );
}
