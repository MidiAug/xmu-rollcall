import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/platform/desktop_qr_scanner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cancel during window creation never shows a late scanner; reuse works',
    () async {
      const windows = MethodChannel('mixin.one/desktop_multi_window');
      const channels = MethodChannel('mixin.one/desktop_multi_window/channels');
      const codec = StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final created = Completer<void>();
      final createResult = Completer<String>();
      var started = Completer<void>();
      final calls = <String>[];
      int? session;
      var failCancel = false;

      Future<void> fromChild(
        String method,
        Map<String, Object?> arguments,
      ) async {
        final done = Completer<void>();
        ServicesBinding.instance.channelBuffers.push(
          channels.name,
          codec.encodeMethodCall(
            MethodCall('methodCall', {
              'channel': 'mixin.one/window_controller/owner',
              'method': method,
              'arguments': arguments,
            }),
          ),
          (_) => done.complete(),
        );
        await done.future;
      }

      messenger.setMockMethodCallHandler(windows, (call) async {
        if (call.method == 'getWindowDefinition') {
          return {'windowId': 'owner', 'windowArgument': ''};
        }
        if (call.method == 'createWindow') {
          calls.add('create');
          created.complete();
          return createResult.future;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(channels, (call) async {
        if (call.method == 'invokeMethod') {
          final args = call.arguments as Map;
          calls.add(args['method'] as String);
          if (args['method'] == 'scan_cancel' && failCancel) {
            throw PlatformException(code: 'window_gone');
          }
          if (args['method'] == 'scan_start') {
            session = (args['arguments'] as Map)['sessionId'] as int;
            started.complete();
          }
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(windows, null);
        messenger.setMockMethodCallHandler(channels, null);
      });

      final canceled = DesktopQrScanner.open(preview: true);
      await created.future;
      await DesktopQrScanner.cancel();
      createResult.complete('scanner');
      expect(await canceled, isNull);
      expect(calls, ['create']);

      // The hidden engine can finish initializing after the page was dismissed.
      await fromChild('qr_ready', {'windowId': 'scanner'});
      final reopened = DesktopQrScanner.open(preview: true);
      await started.future;
      await expectLater(DesktopQrScanner.open(preview: true), throwsStateError);
      var completed = false;
      reopened.then((_) => completed = true);
      // A late result from the canceled session must not close the new one.
      await fromChild('qr_complete', {
        'sessionId': session! - 1,
        'raw': 'stale',
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      await fromChild('qr_complete', {'sessionId': session, 'raw': 'current'});
      expect(await reopened, 'current');
      expect(calls, ['create', 'scan_start']);

      started = Completer<void>();
      final closing = DesktopQrScanner.open(preview: true);
      await started.future;
      failCancel = true;
      // Even if the child disappears, cancellation must release the page.
      await DesktopQrScanner.cancel();
      expect(await closing, isNull);
      await DesktopQrScanner.cancel();
      started = Completer<void>();
      failCancel = false;
      final afterCancel = DesktopQrScanner.open(preview: true);
      await started.future;
      await fromChild('qr_complete', {'sessionId': session, 'raw': null});
      expect(await afterCancel, isNull);
    },
    skip: !DesktopQrScanner.supported,
  );
}
