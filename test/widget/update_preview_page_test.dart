import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/update/update_preview_page.dart';

void main() {
  testWidgets(
    'diagnostic update preview switches scenarios and uses real notes dialog',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const UpdatePreviewPage()),
      );
      await tester.pumpAndSettle();
      expect(find.text('更新流程预览'), findsOneWidget);
      expect(find.text('有更新 · v0.1.4'), findsOneWidget);
      await tester.tap(find.text('有更新 · v0.1.4'));
      await tester.pumpAndSettle();
      expect(find.text('更新说明'), findsOneWidget);
      expect(find.byType(MarkdownBody), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('update-preview-scenario')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('检查失败').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('暂时无法检查'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
