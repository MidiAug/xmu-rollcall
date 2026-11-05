import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/chrome.dart';
import 'package:xmu_rollcall/core/session/assist_identity.dart';
import 'package:xmu_rollcall/core/session/session_credential.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import 'package:xmu_rollcall/features/rollcall/rollcall_account_menu.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      'masthead identity selection keeps callback and platform style $platform',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light().copyWith(platform: platform),
            home: Scaffold(
              body: RollcallAccountMenu(
                masthead: true,
                value: 0,
                ownerName: '主账号',
                identities: const [
                  AssistIdentity(
                    userId: 2,
                    displayName: '协助同学',
                    kind: AssistCredentialKind.session,
                    deviceId: 'test-device',
                  ),
                ],
                onChanged: (value) => selected = value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(AppSelectTrigger),
          platform == TargetPlatform.android ? findsNothing : findsOneWidget,
        );
        await tester.tap(find.text('主账号'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('协助同学'));
        await tester.pumpAndSettle();
        expect(selected, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
