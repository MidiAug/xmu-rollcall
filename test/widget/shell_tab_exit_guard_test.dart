import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmu_rollcall/app/app_dialogs.dart';
import 'package:xmu_rollcall/app/app_toast.dart';
import 'package:xmu_rollcall/app/destinations.dart';
import 'package:xmu_rollcall/app/shell_destination_scope.dart';
import 'package:xmu_rollcall/app/shell_tab_exit_guard.dart';
import 'package:xmu_rollcall/core/theme/app_theme.dart';
import '../fixtures/desktop_ui_capture.dart';
import '../fixtures/preview_fonts.dart';

void main() {
  initializeDesktopUiCapture();
  setUpAll(loadDesktopPreviewFonts);
  for (final dark in [false, true]) {
    for (final width in [320.0, 1100.0]) {
      testWidgets(
        'tab exit confirmation keeps cancel, busy and discard behavior $dark/$width',
        (tester) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = ShellTabExitController();
          var dirty = false, busy = false;
          late BuildContext routeContext;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              builder: (context, child) => RepaintBoundary(
                key: const ValueKey('desktop-ui-capture'),
                child: child!,
              ),
              home: ShellTabExitScope(
                controller: controller,
                child: ShellTabDestination(
                  destination: AppDestination.settings,
                  child: Scaffold(
                    body: Builder(
                      builder: (context) {
                        routeContext = context;
                        return ShellTabExitGuard(
                          hasUnsavedChanges: () => dirty,
                          isBusy: () => busy,
                          child: const Center(child: Text('编辑课程地点')),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            controller.canLeave(routeContext, AppDestination.settings),
            isTrue,
          );
          dirty = true;
          final canceled = controller.canLeave(
            routeContext,
            AppDestination.settings,
          );
          await tester.pumpAndSettle();
          expect(find.byType(AppDialogFrame), findsOneWidget);
          await captureDesktopUi(tester, 'guard-confirm-$dark-$width');
          await tester.tap(find.text('继续编辑'));
          await tester.pumpAndSettle();
          expect(await canceled, isFalse);
          expect(find.byType(AppDialogFrame), findsNothing);

          final becameBusy = controller.canLeave(
            routeContext,
            AppDestination.settings,
          );
          await tester.pumpAndSettle();
          busy = true;
          await tester.tap(find.text('放弃并离开'));
          await tester.pumpAndSettle();
          expect(await becameBusy, isFalse);
          expect(
            controller.canLeave(routeContext, AppDestination.settings),
            isFalse,
          );
          AppToast.dismiss();
          busy = false;
          final discarded = controller.canLeave(
            routeContext,
            AppDestination.settings,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('放弃并离开'));
          await tester.pumpAndSettle();
          expect(await discarded, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
