import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

class _Location extends GeolocatorPlatform {
  Future<bool> Function() service = () async => true;
  Future<LocationPermission> Function() permission = () async =>
      LocationPermission.whileInUse;
  final position = Completer<Position>();
  LocationSettings? settings;
  @override
  Future<bool> isLocationServiceEnabled() => service();
  @override
  Future<LocationPermission> checkPermission() => permission();
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    settings = locationSettings;
    return position.future;
  }
}

void main() {
  late GeolocatorPlatform original;
  late _Location location;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = GeolocatorPlatform.instance;
    location = _Location();
    GeolocatorPlatform.instance = location;
  });
  tearDown(() => GeolocatorPlatform.instance = original);
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RollcallAnswerPage(
            item: RollcallItem(
              rollcallId: 1,
              courseTitle: 'course',
              createdByName: 'teacher',
              type: RollcallType.radar,
              status: 'on_call',
              rollcallStatus: 'on_call',
              isExpired: false,
              scored: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择位置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('使用当前定位'));
    await tester.pumpAndSettle();
  }

  testWidgets('permission API exception is contained', (tester) async {
    location.permission = () async => throw StateError('permission API failed');
    await open(tester);
    expect(find.text('定位失败，可改用地图选点或已保存地点'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('leaving during service check ignores late result', (
    tester,
  ) async {
    final pending = Completer<bool>();
    location.service = () => pending.future;
    await open(tester);
    await tester.pumpWidget(const SizedBox());
    pending.complete(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('position lookup has a deadline and a usable timeout message', (
    tester,
  ) async {
    await open(tester);
    expect(location.settings?.timeLimit, const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    expect(find.text('定位超时，可重试或改用地图选点 / 已保存地点'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
