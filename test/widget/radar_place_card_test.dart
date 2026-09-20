import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_answer_page.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'radar answer shows a confirmation card instead of three source buttons',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const RollcallAnswerPage(
              item: RollcallItem(
                rollcallId: 1,
                courseTitle: '工程伦理',
                createdByName: '薛镖',
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

      expect(find.text('尚未选择位置'), findsOneWidget);
      expect(find.text('更换位置'), findsOneWidget);
      expect(find.text('用此位置签到'), findsOneWidget);
      expect(find.text('定位'), findsNothing);
      expect(find.text('地图'), findsNothing);
      expect(find.text('预设'), findsNothing);
    },
  );
}
