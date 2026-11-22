import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/core/theme/app_tokens.dart';

import '../fixtures/preview_fonts.dart';

String _normalizePath(String path) => path.replaceAll('\\', '/');

List<File> _scanDartFiles(List<String> roots) {
  final files = <File>[];
  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    files.addAll(
      dir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart')),
    );
  }
  files.sort(
    (a, b) => _normalizePath(a.path).compareTo(_normalizePath(b.path)),
  );
  return files;
}

Future<void> _pumpWithDensity(
  WidgetTester tester, {
  required Size size,
  required TargetPlatform platform,
  required Widget child,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light().copyWith(platform: platform),
      home: AppDensityScope(
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadDesktopPreviewFonts);

  group('UI architecture token invariants', () {
    test('AppDensity exposes four-tier control height tokens', () {
      expect(AppDensity.controlHeightCompact, 32.0);
      expect(AppDensity.controlHeightToolbar, 36.0);
      expect(AppDensity.controlHeightRegular, 40.0);
      expect(AppDensity.controlHeightTouch, 44.0);
    });
  });

  group('UI architecture static source gates', () {
    test('forbids ChoiceChip and FilterChip in lib/app and lib/features', () {
      final files = _scanDartFiles(const ['lib/app', 'lib/features']);
      expect(files, isNotEmpty);
      final chipPattern = RegExp(r'\b(?:ChoiceChip|FilterChip)\s*\(');
      final violations = <String>[];
      for (final file in files) {
        final path = _normalizePath(file.path);
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (chipPattern.hasMatch(lines[i])) {
            violations.add('$path:${i + 1}');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Forbidden ChoiceChip/FilterChip usage: $violations',
      );
    });

    test('forbids raw InkWell in lib/features outside legacy allowlist', () {
      const allowlist = {'lib/features/location/campus_map.dart'};
      final files = _scanDartFiles(const ['lib/features']);
      expect(files, isNotEmpty);
      final inkWellPattern = RegExp(r'\bInkWell\s*\(');
      final violations = <String>[];
      for (final file in files) {
        final path = _normalizePath(file.path);
        if (allowlist.contains(path)) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (inkWellPattern.hasMatch(lines[i])) {
            violations.add('$path:${i + 1}');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Forbidden raw InkWell usage in features: $violations',
      );
    });

    test(
      'forbids middle-dot separators in string literals in lib/app and lib/features',
      () {
        const allowlist = {
          'lib/features/location/campus_story_research.dart',
          'lib/features/schedule/academic_schedule.dart',
        };
        final files = _scanDartFiles(const ['lib/app', 'lib/features']);
        expect(files, isNotEmpty);
        final dotPattern = RegExp(r'[\u00B7\u2022\u22C5]');
        final literalWithDot = RegExp(
          r'''(['"])([^'"\n]*[\u00B7\u2022\u22C5][^'"\n]*)\1''',
        );
        final violations = <String>[];
        for (final file in files) {
          final path = _normalizePath(file.path);
          if (allowlist.contains(path)) continue;
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (!dotPattern.hasMatch(line)) continue;
            if (literalWithDot.hasMatch(line)) {
              violations.add('$path:${i + 1}');
            }
          }
        }
        expect(
          violations,
          isEmpty,
          reason: 'Forbidden middle-dot string literals: $violations',
        );
      },
    );
  });

  group('Shared control four-tier height contract', () {
    testWidgets('desktop density heights and badge intrinsic width', (
      tester,
    ) async {
      const selectCompactKey = ValueKey('desktop-select-compact');
      const selectToolbarKey = ValueKey('desktop-select-toolbar');
      const searchCompactKey = ValueKey('desktop-search-compact');
      const segmentRegularKey = ValueKey('desktop-segment-regular');
      const segmentCompactKey = ValueKey('desktop-segment-compact');
      const inlineButtonKey = ValueKey('desktop-inline-outlined');
      const badgeKey = ValueKey('desktop-status-badge');

      await _pumpWithDensity(
        tester,
        size: const Size(1120, 780),
        platform: TargetPlatform.windows,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 240,
              child: AppSelectTrigger(
                key: selectCompactKey,
                label: '全部学期',
                compact: true,
                onTap: () {},
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 240,
              child: AppSelectTrigger(
                key: selectToolbarKey,
                label: '全部课程',
                compact: false,
                onTap: () {},
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 240,
              child: AppSearchField(
                key: searchCompactKey,
                hintText: '搜索',
                compact: true,
              ),
            ),
            const SizedBox(height: 12),
            AppSegmentedControl<int>(
              key: segmentRegularKey,
              segments: const [
                AppSegment(value: 0, label: '全部'),
                AppSegment(value: 1, label: '未签'),
              ],
              value: 0,
              onChanged: (_) {},
            ),
            const SizedBox(height: 12),
            AppSegmentedControl<int>(
              key: segmentCompactKey,
              segments: const [
                AppSegment(value: 0, label: '全部'),
                AppSegment(value: 1, label: '未签'),
              ],
              value: 0,
              compact: true,
              onChanged: (_) {},
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) => OutlinedButton(
                key: inlineButtonKey,
                style: AppControlStyle.inlineOutlined(context),
                onPressed: () {},
                child: const Text('检查'),
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 96,
              child: AppStatusBadge('未提交', key: badgeKey),
            ),
          ],
        ),
      );

      expect(tester.getSize(find.byKey(selectCompactKey)).height, 32.0);
      expect(tester.getSize(find.byKey(selectToolbarKey)).height, 36.0);
      expect(tester.getSize(find.byKey(searchCompactKey)).height, 36.0);
      expect(tester.getSize(find.byKey(segmentRegularKey)).height, 36.0);
      expect(tester.getSize(find.byKey(segmentCompactKey)).height, 32.0);
      expect(tester.getSize(find.byKey(inlineButtonKey)).height, 32.0);

      final innerBadgeBox = find.descendant(
        of: find.byKey(badgeKey),
        matching: find.byType(DecoratedBox),
      );
      expect(innerBadgeBox, findsOneWidget);
      final badgeSize = tester.getSize(innerBadgeBox);
      expect(badgeSize.width, lessThan(96));
      expect(badgeSize.height, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('mobile touch density heights', (tester) async {
      const searchCompactKey = ValueKey('mobile-search-compact');
      const searchRegularKey = ValueKey('mobile-search-regular');
      const selectCompactKey = ValueKey('mobile-select-compact');
      const selectRegularKey = ValueKey('mobile-select-regular');

      await _pumpWithDensity(
        tester,
        size: const Size(390, 844),
        platform: TargetPlatform.iOS,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 240,
              child: AppSearchField(
                key: searchCompactKey,
                hintText: '搜索',
                compact: true,
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 240,
              child: AppSearchField(
                key: searchRegularKey,
                hintText: '搜索',
                compact: false,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 240,
              child: AppSelectTrigger(
                key: selectCompactKey,
                label: '全部课程',
                compact: true,
                onTap: () {},
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 240,
              child: AppSelectTrigger(
                key: selectRegularKey,
                label: '全部课程',
                compact: false,
                onTap: () {},
              ),
            ),
          ],
        ),
      );

      expect(tester.getSize(find.byKey(searchCompactKey)).height, 40.0);
      expect(tester.getSize(find.byKey(searchRegularKey)).height, 44.0);
      expect(tester.getSize(find.byKey(selectCompactKey)).height, 44.0);
      expect(tester.getSize(find.byKey(selectRegularKey)).height, 48.0);
      expect(tester.takeException(), isNull);
    });
  });
}
