import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/features/update/update_download_route.dart';
import 'package:xmu_rollcall/features/update/update_download_route_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'download route persists and rejects credentials, local endpoints and path injection',
    () async {
      expect(await UpdateDownloadRoute.read(), isNull);
      await UpdateDownloadRoute.save('https://ghproxy.net');
      await (await SharedPreferences.getInstance()).reload();
      expect(
        (await UpdateDownloadRoute.read()).toString(),
        'https://ghproxy.net/',
      );
      for (final invalid in [
        'http://ghproxy.net/',
        'https://user:pass@mirror.example/',
        'https://127.0.0.1/',
        'https://localhost/',
        'https://mirror.local/',
        'https://mirror.example/payload',
        'https://mirror.example/?token=secret',
        'https://mirror.example/#fragment',
        'https://mirror.example:8443/',
      ]) {
        expect(() => UpdateDownloadRoute.parse(invalid), throwsFormatException);
      }
      await UpdateDownloadRoute.save(null);
      expect(await UpdateDownloadRoute.read(), isNull);
    },
  );
  testWidgets(
    'narrow route dialog validates custom URL and saves/reopens selected mirror',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showUpdateDownloadRouteDialog(context),
                child: const Text('线路'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('线路'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('其他 HTTPS 节点').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'http://bad.example/');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.textContaining('请输入 HTTPS'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'https://mirror.example/');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(
        (await UpdateDownloadRoute.read()).toString(),
        'https://mirror.example/',
      );
      await tester.tap(find.text('线路'));
      await tester.pumpAndSettle();
      expect(find.text('https://mirror.example/'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
