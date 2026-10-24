import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/location/location_models.dart';
import 'package:xmu_rollcall/features/location/location_picker.dart';
import 'package:xmu_rollcall/features/location/location_providers.dart';
import 'package:xmu_rollcall/features/location/map_pick_panel.dart';

class _SlowSave extends SavedLocationsController {
  final gate = Completer<void>();
  int calls = 0;
  @override
  Future<SavedLocation> add({
    required String note,
    required double latitude,
    required double longitude,
    double accuracy = 35,
  }) async {
    calls++;
    if (calls == 1) {
      await gate.future;
      throw StateError('isolated save failure');
    }
    return super.add(
      note: note,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    final cache = await Directory(
      '.tools/location-picker/cache',
    ).create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => cache.absolute.path,
        );
    final font = Platform.environment['MONITOR_UI_FONT'];
    if (font == null) return;
    await (FontLoader(
      'LocationUi',
    )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader('MaterialIcons')..addFont(
          File(
            Platform.environment['MONITOR_UI_ICONS']!,
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });

  for (final scenario in [
    (960.0, false, 1.0),
    (960.0, true, 1.0),
    (384.0, false, 1.0),
    (320.0, true, 1.3),
  ]) {
    testWidgets(
      'one location panel retains drafts and handles keyboard at $scenario',
      (tester) async {
        tester.view.physicalSize = Size(scenario.$1, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(savedLocationsProvider.notifier);
        final place = await controller.add(
          note: '学武楼 301 · 原有教室',
          latitude: 24.6,
          longitude: 118.3,
        );
        await controller.add(
          note: '一条很长的地点备注，用于确认窄屏上完整换行后仍然可以选择且不影响旁边图标对齐',
          latitude: 24.7,
          longitude: 118.4,
        );
        SavedLocation? result;
        var theme = scenario.$2 ? AppTheme.dark() : AppTheme.light();
        if (Platform.environment['MONITOR_UI_FONT'] != null) {
          theme = theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'LocationUi'),
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(
              labelStyle: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'LocationUi',
              ),
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'LocationUi',
              ),
              errorStyle: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'LocationUi',
              ),
            ),
          );
        }
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scenario.$3)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async => result = await showLocationPicker(
                        context,
                        title: '选择上课地点',
                        selectedId: place.id,
                      ),
                      child: const Text('打开'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> capture(String name) async {
          expect(tester.takeException(), isNull);
          if (Platform.environment['CAPTURE_LOCATION_PICKER'] != '1') return;
          await tester.runAsync(() async {
            final dir = await Directory(
              '.tools/location-picker',
            ).create(recursive: true);
            final img =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '${dir.path}/${scenario.$1.toInt()}-${scenario.$2 ? 'dark' : 'light'}-$name.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }

        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        await capture('01-list');
        await tester.tap(find.text('添加地点'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await capture('02-add');
        await tester.enterText(find.byType(TextField), '新的教室备注');
        await tester.tapAt(
          tester.getCenter(find.byType(FlutterMap)) + const Offset(20, -10),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 400));
        final point = tester
            .state<MapPickPanelState>(find.byType(MapPickPanel))
            .point;
        await tester.tap(find.byTooltip('返回地点列表'));
        await tester.pumpAndSettle();
        expect(find.byType(MapPickPanel), findsNothing);
        expect(container.read(savedLocationsProvider).length, 2);
        await tester.tap(find.text('添加地点'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '新的教室备注',
        );
        expect(
          tester.state<MapPickPanelState>(find.byType(MapPickPanel)).point,
          point,
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextField));
        await tester.pumpAndSettle();
        await capture('03-keyboard');
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('保存并使用'));
        await tester.tap(find.text('保存并使用'));
        await tester.pumpAndSettle();
        expect(result!.note, '新的教室备注');
        expect(result!.latitude, point.latitude);
        expect(container.read(savedLocationsProvider).length, 3);
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('closing a draft leaves stored places unchanged', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLocationPicker(context),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加地点'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '不保存');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MapPickPanel), findsNothing);
    await tester.tap(find.text('添加地点'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '不保存',
    );
    await tester.tap(find.byTooltip('关闭地点选择'));
    await tester.pumpAndSettle();
    expect(container.read(savedLocationsProvider), isEmpty);
  });

  testWidgets(
    'saving blocks duplicates and closing; failed save retains input for retry',
    (tester) async {
      final slow = _SlowSave();
      final container = ProviderContainer(
        overrides: [savedLocationsProvider.overrideWith((ref) => slow)],
      );
      addTearDown(container.dispose);
      SavedLocation? result;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async =>
                      result = await showLocationPicker(context),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加地点'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '保留备注');
      await tester.tap(find.text('保存并使用'));
      await tester.tap(find.text('保存并使用'));
      await tester.pumpAndSettle();
      expect(slow.calls, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MapPickPanel), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.close_rounded),
            )
            .onPressed,
        isNull,
      );
      slow.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('地点未能保存，请重试'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '保留备注',
      );
      await tester.tap(find.text('保存并使用'));
      await tester.pumpAndSettle();
      expect(slow.calls, 2);
      expect(result!.note, '保留备注');
      expect(container.read(savedLocationsProvider).length, 1);
    },
  );
}
