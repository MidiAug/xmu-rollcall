import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/homework/homework_detail_page.dart';
import 'package:xmu_rollcall/features/homework/homework_models.dart';
import 'package:xmu_rollcall/features/homework/homework_providers.dart';

void main() {
  testWidgets('detail shows 查看该课全部 when courseId present', (tester) async {
    final seed = HomeworkItem(
      id: 7,
      title: 'Essay',
      courseId: 3,
      courseName: 'English',
      dueAt: DateTime.utc(2026, 10, 1),
      status: 'open',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeworkDetailProvider.overrideWith((ref, key) async => seed),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: HomeworkDetailPage(seed: seed),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('查看该课全部'), findsOneWidget);
    expect(find.text('Essay'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('detail hides 查看该课全部 without courseId', (tester) async {
    final seed = const HomeworkItem(id: 8, title: 'No course');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeworkDetailProvider.overrideWith((ref, key) async => seed),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: HomeworkDetailPage(seed: seed),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('查看该课全部'), findsNothing);
    expect(find.textContaining('缺少课程 id'), findsOneWidget);
  });
}
